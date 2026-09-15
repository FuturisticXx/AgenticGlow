import Foundation

public protocol AllowanceCaching: Sendable {
    func save(_ allowance: ProviderAllowance) throws
    func load(_ provider: AgentProvider) throws -> ProviderAllowance?
    func remove(_ provider: AgentProvider) throws
}

public final class FileAllowanceCache: AllowanceCaching, @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ allowance: ProviderAllowance) throws {
        try ensureDirectory()
        let url = fileURL(for: allowance.provider)
        try encoder.encode(allowance).write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func load(_ provider: AgentProvider) throws -> ProviderAllowance? {
        let url = fileURL(for: provider)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(ProviderAllowance.self, from: Data(contentsOf: url))
    }

    public func remove(_ provider: AgentProvider) throws {
        let url = fileURL(for: provider)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func fileURL(for provider: AgentProvider) -> URL {
        directory.appendingPathComponent("\(provider.rawValue).json")
    }
}
