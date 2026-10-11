import Foundation

public protocol UsageResetStateStoring: Sendable {
    func load() throws -> [UsageWindowKey: UsageWindowEvidence]
    func save(_ evidence: [UsageWindowKey: UsageWindowEvidence]) throws
}

/// Persists the reset detector's evidence next to the allowance cache.
/// Without this, relaunching AgenticGlow while a window is exhausted would
/// start from `.unknown` and re-announce the next reset it happens to see.
///
/// Stored as a flat record list rather than a keyed dictionary because
/// `UsageWindowKey` is not a string, and JSON dictionaries must be.
public final class FileUsageResetStateStore: UsageResetStateStoring, @unchecked Sendable {
    private struct Record: Codable {
        let provider: AgentProvider
        let windowLabel: String
        let availability: UsageAvailability
        let observedAt: Date
    }

    private let url: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL, fileManager: FileManager = .default) {
        self.url = directory.appendingPathComponent("usage-reset-state.json")
        self.fileManager = fileManager
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> [UsageWindowKey: UsageWindowEvidence] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        let records = try decoder.decode([Record].self, from: Data(contentsOf: url))
        return Dictionary(
            records.map { record in
                (
                    UsageWindowKey(provider: record.provider, windowLabel: record.windowLabel),
                    UsageWindowEvidence(
                        availability: record.availability,
                        observedAt: record.observedAt
                    )
                )
            },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    public func save(_ evidence: [UsageWindowKey: UsageWindowEvidence]) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let records = evidence
            .map { key, value in
                Record(
                    provider: key.provider,
                    windowLabel: key.windowLabel,
                    availability: value.availability,
                    observedAt: value.observedAt
                )
            }
            .sorted { ($0.provider.rawValue, $0.windowLabel) < ($1.provider.rawValue, $1.windowLabel) }
        try encoder.encode(records).write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
