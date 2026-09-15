import Foundation

public struct ReleaseMetadata: Codable, Equatable, Sendable {
    public let tagName: String
    public let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

public struct AvailableUpdate: Equatable, Sendable {
    public let version: String
    public let url: URL
}

public protocol UpdateTransporting: Sendable {
    func latestRelease() async throws -> ReleaseMetadata
}

public protocol UpdateChecking: Sendable {
    func check(currentVersion: String, enabled: Bool) async throws -> AvailableUpdate?
}

public struct GitHubReleaseTransport: UpdateTransporting {
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/FuturisticXx/AgenticGlow/releases/latest")!

    public init() {}

    public func latestRelease() async throws -> ReleaseMetadata {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("AgenticGlow", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ReleaseMetadata.self, from: data)
    }
}

public struct GitHubUpdateChecker: UpdateChecking {
    private let transport: UpdateTransporting

    public init(transport: UpdateTransporting = GitHubReleaseTransport()) {
        self.transport = transport
    }

    public func check(currentVersion: String, enabled: Bool) async throws -> AvailableUpdate? {
        guard enabled else { return nil }
        let release = try await transport.latestRelease()
        let remote = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        guard remote.compare(currentVersion, options: .numeric) == .orderedDescending else {
            return nil
        }
        return AvailableUpdate(version: remote, url: release.htmlURL)
    }
}
