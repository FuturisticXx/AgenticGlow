#if DEBUG
import CloudKit
import Foundation
import XCTest
@testable import AgenticGlowCore

final class SyncVerificationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    private func makeEnvelope() -> SyncedStateEnvelope {
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [
                WidgetSessionSummary(
                    provider: .codex, sessionID: "abc", projectName: "AgenticGlow", phase: .thinking,
                    toolCategory: nil, elapsedSeconds: 10, updatedAt: now, needsAttention: false
                )
            ],
            allowances: [
                WidgetAllowanceSummary(
                    provider: .codex, currentWindowLabel: "5h", currentPercentLeft: 50, currentResetAt: now,
                    weeklyPercentLeft: 40, weeklyResetAt: now, fetchedAt: now
                )
            ],
            providers: [WidgetProviderSummary(provider: .codex, installed: true)],
            attentionCount: 0,
            activeCount: 1
        )
        return SyncedStateEnvelope(sourceMacID: UUID().uuidString, sourceMacName: "Mac", observedAt: now, snapshot: snapshot)
    }

    func testAllowlistIsExactlyTheFourDocumentedFields() {
        XCTAssertEqual(SyncRecordAllowlist.fields, ["payload", "schemaVersion", "sourceMacID", "observedAt"])
        XCTAssertEqual(SyncRecordAllowlist.unexpectedFields(in: ["payload", "schemaVersion", "sourceMacID", "observedAt"]), [])
        XCTAssertEqual(SyncRecordAllowlist.unexpectedFields(in: ["payload", "cookie", "observedAt"]), ["cookie"])
        XCTAssertEqual(SyncRecordAllowlist.missingFields(in: ["payload"]), ["observedAt", "schemaVersion", "sourceMacID"])
    }

    func testARealEnvelopeIsCleanAndTheRecordCarriesOnlyAllowedFields() throws {
        let envelope = makeEnvelope()
        XCTAssertEqual(SyncPayloadAudit.findings(in: try SyncedStateCodec.encode(envelope)), [])
        let record = CKRecord(recordType: CloudKitSyncRecord.recordType, recordID: CKRecord.ID(recordName: "latest"))
        try CloudKitSyncRecord.apply(envelope, to: record)
        XCTAssertEqual(SyncRecordAllowlist.unexpectedFields(in: record.allKeys()), [])
        XCTAssertEqual(SyncRecordAllowlist.missingFields(in: record.allKeys()), [])
    }

    func testAuditReportsForbiddenKeysByPathWithoutValues() throws {
        let leaked: [String: Any] = [
            "schemaVersion": 1,
            "snapshot": [
                "sessions": [["projectName": "X", "workingDirectory": "/Users/someone/secret-project"]],
                "sessionCookie": "sk-should-never-appear"
            ]
        ]
        let findings = SyncPayloadAudit.findings(in: try JSONSerialization.data(withJSONObject: leaked))
        XCTAssertEqual(findings, [
            "forbidden key: snapshot.sessionCookie",
            "forbidden key: snapshot.sessions[0].workingDirectory",
            "path-like value at: snapshot.sessions[0].workingDirectory"
        ])
        let joined = findings.joined()
        XCTAssertFalse(joined.contains("secret-project"))
        XCTAssertFalse(joined.contains("sk-should"))
    }

    func testAuditFlagsPathLikeValuesUnderInnocentKeys() throws {
        let leaked: [String: Any] = ["snapshot": ["sessions": [["projectName": "/Volumes/Liquid/Repo"]]]]
        XCTAssertEqual(
            SyncPayloadAudit.findings(in: try JSONSerialization.data(withJSONObject: leaked)),
            ["path-like value at: snapshot.sessions[0].projectName"]
        )
        XCTAssertEqual(SyncPayloadAudit.findings(in: Data("nope".utf8)), ["<payload is not JSON>"])
    }

    func testFingerprintIsStableAndBlindToContent() throws {
        let envelope = makeEnvelope()
        let hash = SyncedStateFingerprint.hash(of: envelope)
        XCTAssertEqual(hash.count, 12)
        XCTAssertEqual(hash, SyncedStateFingerprint.hash(of: envelope))
        XCTAssertFalse(hash.contains("AgenticGlow"))
        let other = SyncedStateEnvelope(sourceMacID: envelope.sourceMacID, sourceMacName: "Other", observedAt: now, snapshot: envelope.snapshot)
        XCTAssertNotEqual(hash, SyncedStateFingerprint.hash(of: other))
    }

    func testRoundTripVerifierPassesAgainstAFaithfulTransport() async throws {
        let transport = FakeVerificationTransport()
        let report = await SyncRoundTripVerifier.verify(makeEnvelope(), transport: transport, policy: SyncVerificationPolicy(attempts: 1, delay: .zero))
        XCTAssertTrue(report.passed, report.text)
        XCTAssertTrue(report.text.contains("Record latest round trip: PASS"))
        XCTAssertTrue(report.text.contains("forbidden fields: none"))
        XCTAssertFalse(report.text.contains("AgenticGlow"), "the report never quotes payload content")
    }

    func testRoundTripVerifierFailsOnAnExtraFieldAndNamesIt() async throws {
        let transport = FakeVerificationTransport()
        transport.extraField = ("sessionCookie", "leaked" as NSString)
        let report = await SyncRoundTripVerifier.verify(makeEnvelope(), transport: transport, policy: SyncVerificationPolicy(attempts: 1, delay: .zero))
        XCTAssertFalse(report.passed)
        XCTAssertTrue(report.text.contains("unexpected fields: sessionCookie"))
        XCTAssertFalse(report.text.contains("leaked"))
    }

    func testRoundTripVerifierFailsWhenTheFetchedPayloadDiffers() async throws {
        let transport = FakeVerificationTransport()
        transport.tamper = true
        let report = await SyncRoundTripVerifier.verify(makeEnvelope(), transport: transport, policy: SyncVerificationPolicy(attempts: 1, delay: .zero))
        XCTAssertFalse(report.passed)
        XCTAssertTrue(report.text.contains("round trip: FAIL"))
    }

    func testRoundTripVerifierStopsWithoutAnAccount() async {
        let transport = FakeVerificationTransport()
        transport.status = .noAccount
        let report = await SyncRoundTripVerifier.verify(makeEnvelope(), transport: transport)
        XCTAssertFalse(report.passed)
        XCTAssertEqual(transport.published.count, 0)
    }
}

/// Stores records in memory exactly as CloudKit would hand them back.
private final class FakeVerificationTransport: SyncVerificationTransport, @unchecked Sendable {
    var status: CKAccountStatus = .available
    var extraField: (String, NSString)?
    var tamper = false
    private(set) var published: [SyncedStateEnvelope] = []
    private var records: [String: CKRecord] = [:]

    func accountStatusForVerification() async throws -> CKAccountStatus { status }

    func publish(_ envelope: SyncedStateEnvelope) async throws {
        published.append(envelope)
        for name in [CloudKitSyncRecord.latestRecordName, CloudKitSyncRecord.perMacRecordName(sourceMacID: envelope.sourceMacID)] {
            let record = CKRecord(recordType: CloudKitSyncRecord.recordType, recordID: CKRecord.ID(recordName: name))
            var stored = envelope
            if tamper {
                stored = SyncedStateEnvelope(sourceMacID: envelope.sourceMacID, sourceMacName: "Tampered", observedAt: envelope.observedAt, snapshot: envelope.snapshot)
            }
            try CloudKitSyncRecord.apply(stored, to: record)
            if let extraField { record[extraField.0] = extraField.1 }
            records[name] = record
        }
    }

    func fetchRecordForVerification(recordName: String) async throws -> CKRecord {
        guard let record = records[recordName] else { throw CKError(.unknownItem) }
        return record
    }
}
#endif
