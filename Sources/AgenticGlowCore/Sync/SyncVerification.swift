#if DEBUG
import CloudKit
import CryptoKit
import Foundation

/// A short, stable fingerprint of an envelope: the SHA-256 of its
/// canonical encoding (sorted keys), so two devices holding the same
/// state print the same twelve hex characters and nothing about the
/// state itself.
public enum SyncedStateFingerprint {
    public static func hash(of envelope: SyncedStateEnvelope) -> String {
        guard let data = try? SyncedStateCodec.encode(envelope) else { return "unencodable" }
        return hash(of: data)
    }

    public static func hash(of data: Data) -> String {
        SHA256.hash(data: data).prefix(6).map { String(format: "%02x", $0) }.joined()
    }
}

/// The exact set of custom fields a synchronized record may carry.
/// `CKRecord.allKeys()` reports custom fields only, so system fields
/// (record name, change tag, timestamps) are outside this check.
public enum SyncRecordAllowlist {
    public static let fields: Set<String> = [
        CloudKitSyncRecord.payloadKey,
        CloudKitSyncRecord.schemaVersionKey,
        CloudKitSyncRecord.sourceMacIDKey,
        CloudKitSyncRecord.observedAtKey
    ]

    /// Field names present on the record that the allowlist does not
    /// name. Empty means the record carries exactly the documented
    /// fields, which is the pass condition.
    public static func unexpectedFields(in keys: [String]) -> [String] {
        keys.filter { !fields.contains($0) }.sorted()
    }

    public static func missingFields(in keys: [String]) -> [String] {
        fields.subtracting(keys).sorted()
    }
}

/// Searches the encoded payload for anything that should never be in it.
/// Reports key paths only, never values, so a failure can be read aloud
/// without exposing what leaked.
public enum SyncPayloadAudit {
    /// Matched case-insensitively against every key name in the payload.
    public static let forbiddenKeyPatterns: [String] = [
        "token", "cookie", "authorization", "credential", "password",
        "secret", "keychain", "workingdirectory", "sourcebundleid",
        "sourceprocess", "transcript", "prompt", "response", "path"
    ]

    /// Matched against every string value: a value that looks like a
    /// filesystem location is reported by its key, not its content.
    public static let forbiddenValuePrefixes: [String] = [
        "/Users/", "/Volumes/", "/private/", "/var/", "/tmp/", "/Library/", "~/", "file://"
    ]

    /// Every key path that trips a rule, in document order. Empty means
    /// the payload is clean.
    public static func findings(in payload: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: payload) else {
            return ["<payload is not JSON>"]
        }
        var findings: [String] = []
        walk(object, path: "", into: &findings)
        return findings
    }

    private static func walk(_ node: Any, path: String, into findings: inout [String]) {
        switch node {
        case let dictionary as [String: Any]:
            for key in dictionary.keys.sorted() {
                let keyPath = path.isEmpty ? key : "\(path).\(key)"
                let lowered = key.lowercased()
                if forbiddenKeyPatterns.contains(where: { lowered.contains($0) }) {
                    findings.append("forbidden key: \(keyPath)")
                }
                walk(dictionary[key]!, path: keyPath, into: &findings)
            }
        case let array as [Any]:
            for (index, element) in array.enumerated() {
                walk(element, path: "\(path)[\(index)]", into: &findings)
            }
        case let string as String:
            if forbiddenValuePrefixes.contains(where: { string.hasPrefix($0) }) || string.contains("/Users/") {
                findings.append("path-like value at: \(path)")
            }
        default:
            break
        }
    }
}

/// What a round-trip verification needs from a transport, beyond what
/// production uses: reading a record back by its known identifier.
public protocol SyncVerificationTransport: SyncedStatePublishing {
    func accountStatusForVerification() async throws -> CKAccountStatus
    func fetchRecordForVerification(recordName: String) async throws -> CKRecord
}

/// One line of a verification report, with its verdict.
public struct SyncVerificationLine: Equatable, Sendable {
    public let label: String
    public let value: String
    public let passed: Bool

    public init(_ label: String, _ value: String, passed: Bool = true) {
        self.label = label
        self.value = value
        self.passed = passed
    }

    public var text: String { "\(label): \(value)" }
}

public struct SyncVerificationReport: Equatable, Sendable {
    public var lines: [SyncVerificationLine] = []

    public init() {}
    public var passed: Bool { lines.allSatisfy(\.passed) }
    public var text: String { lines.map(\.text).joined(separator: "\n") }

    public mutating func add(_ label: String, _ value: String, passed: Bool = true) {
        lines.append(SyncVerificationLine(label, value, passed: passed))
    }
}

/// Bounded retry for reading a record back: CloudKit's private database
/// is read-after-write consistent in practice, but the verification does
/// not assume it.
public struct SyncVerificationPolicy: Sendable {
    public var attempts: Int
    public var delay: Duration

    public init(attempts: Int = 5, delay: Duration = .seconds(2)) {
        self.attempts = attempts
        self.delay = delay
    }
}

/// Publishes an envelope through the real transport and proves, from the
/// same CloudKit container, that what came back is exactly what went up:
/// only the documented fields, decodable by the iPhone's decoder, equal
/// to the published envelope, and free of anything the privacy contract
/// forbids. Never prints the payload.
public enum SyncRoundTripVerifier {
    public static func verify(
        _ envelope: SyncedStateEnvelope,
        transport: any SyncVerificationTransport,
        policy: SyncVerificationPolicy = SyncVerificationPolicy(),
        now: @Sendable () -> Date = Date.init
    ) async -> SyncVerificationReport {
        var report = SyncVerificationReport()
        let stamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let expectedHash = SyncedStateFingerprint.hash(of: envelope)
        report.add("Verification started", now().formatted(stamp))
        report.add("Published snapshot hash", expectedHash)
        // What the published bytes decode to. The snapshot's own dates are
        // fractional and do not round-trip bit-for-bit through the wire
        // format, so the fetched record is held to this, not to the
        // in-memory value: equal bytes (the hash) and an equal decode.
        let expected: SyncedStateEnvelope
        do {
            expected = try SyncedStateCodec.decode(try SyncedStateCodec.encode(envelope))
        } catch {
            report.add("Encode", "FAIL: \(error)", passed: false)
            return report
        }

        do {
            let status = try await transport.accountStatusForVerification()
            report.add("CloudKit account", describe(status), passed: status == .available)
            guard status == .available else { return report }
        } catch {
            report.add("CloudKit account", "error: \(error.localizedDescription)", passed: false)
            return report
        }

        let publishStarted = now()
        do {
            try await transport.publish(envelope)
            let elapsed = now().timeIntervalSince(publishStarted)
            report.add("Publish", "PASS (\(String(format: "%.2f", elapsed))s)")
        } catch {
            report.add("Publish", "FAIL: \(error.localizedDescription)", passed: false)
            return report
        }

        for recordName in [
            CloudKitSyncRecord.latestRecordName,
            CloudKitSyncRecord.perMacRecordName(sourceMacID: envelope.sourceMacID)
        ] {
            await verifyRecord(
                named: recordName,
                against: expected,
                expectedHash: expectedHash,
                transport: transport,
                policy: policy,
                now: now,
                report: &report
            )
        }
        report.add("Verification finished", now().formatted(stamp))
        report.add("Result", report.passed ? "PASS" : "FAIL", passed: report.passed)
        return report
    }

    private static func verifyRecord(
        named recordName: String,
        against envelope: SyncedStateEnvelope,
        expectedHash: String,
        transport: any SyncVerificationTransport,
        policy: SyncVerificationPolicy,
        now: @Sendable () -> Date,
        report: inout SyncVerificationReport
    ) async {
        let label = "Record \(recordName)"
        var record: CKRecord?
        var lastError: Error?
        let started = now()
        for attempt in 1...max(1, policy.attempts) {
            do {
                record = try await transport.fetchRecordForVerification(recordName: recordName)
                report.add("\(label) fetch", "PASS (attempt \(attempt), \(String(format: "%.2f", now().timeIntervalSince(started)))s)")
                break
            } catch {
                lastError = error
                if attempt < policy.attempts { try? await Task.sleep(for: policy.delay) }
            }
        }
        guard let record else {
            report.add("\(label) fetch", "FAIL: \(lastError?.localizedDescription ?? "no record")", passed: false)
            return
        }

        let keys = record.allKeys()
        let unexpected = SyncRecordAllowlist.unexpectedFields(in: keys)
        let missing = SyncRecordAllowlist.missingFields(in: keys)
        report.add("\(label) schema", unexpected.isEmpty && missing.isEmpty ? "PASS" : "FAIL", passed: unexpected.isEmpty && missing.isEmpty)
        report.add("\(label) unexpected fields", unexpected.isEmpty ? "none" : unexpected.joined(separator: ", "), passed: unexpected.isEmpty)
        if !missing.isEmpty {
            report.add("\(label) missing fields", missing.joined(separator: ", "), passed: false)
        }

        guard let payload = record[CloudKitSyncRecord.payloadKey] as? Data else {
            report.add("\(label) payload", "FAIL: missing or not Data", passed: false)
            return
        }
        report.add("\(label) payload bytes", "\(payload.count)")
        let findings = SyncPayloadAudit.findings(in: payload)
        report.add("\(label) forbidden fields", findings.isEmpty ? "none" : findings.joined(separator: "; "), passed: findings.isEmpty)

        let decoded: SyncedStateEnvelope
        do {
            decoded = try CloudKitSyncRecord.envelope(from: record)
            report.add("\(label) decode (iOS decoder)", "PASS")
        } catch {
            report.add("\(label) decode (iOS decoder)", "FAIL: \(error)", passed: false)
            return
        }
        let actualHash = SyncedStateFingerprint.hash(of: decoded)
        report.add("\(label) round trip", decoded == envelope ? "PASS" : "FAIL", passed: decoded == envelope)
        report.add("\(label) Mac ID", decoded.sourceMacID == envelope.sourceMacID ? "matches" : "differs", passed: decoded.sourceMacID == envelope.sourceMacID)
        report.add("\(label) observedAt", decoded.observedAt == envelope.observedAt ? "matches" : "differs", passed: decoded.observedAt == envelope.observedAt)
        report.add("\(label) snapshot hash", actualHash == expectedHash ? "matches (\(actualHash))" : "differs (\(actualHash))", passed: actualHash == expectedHash)
        report.add("\(label) loose observedAt field", (record[CloudKitSyncRecord.observedAtKey] as? Date) == envelope.observedAt ? "matches" : "differs", passed: (record[CloudKitSyncRecord.observedAtKey] as? Date) == envelope.observedAt)
    }

    private static func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: "available"
        case .noAccount: "no account"
        case .restricted: "restricted"
        case .couldNotDetermine: "could not determine"
        case .temporarilyUnavailable: "temporarily unavailable"
        @unknown default: "unknown"
        }
    }
}

extension CloudKitSyncTransport: SyncVerificationTransport {
    public func accountStatusForVerification() async throws -> CKAccountStatus {
        try await Self.accountStatus(containerIdentifier: containerIdentifier)
    }

    public func fetchRecordForVerification(recordName: String) async throws -> CKRecord {
        try await database.record(for: CKRecord.ID(recordName: recordName))
    }
}
#endif
