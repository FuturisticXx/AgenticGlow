import Foundation

public protocol ProviderStatusRequesting: Sendable {
    func fetchStatus(for provider: AgentProvider) async throws -> Data
}

/// Fetches the public, unauthenticated Statuspage summary for a provider.
/// Nothing account-related or identifying is sent; the request is a plain
/// GET to a documented public endpoint.
public struct StatusPageClient: ProviderStatusRequesting {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public static func endpoint(for provider: AgentProvider) -> URL {
        switch provider {
        case .claude:
            URL(string: "https://status.claude.com/api/v2/status.json")!
        case .codex:
            URL(string: "https://status.openai.com/api/v2/status.json")!
        }
    }

    public func fetchStatus(for provider: AgentProvider) async throws -> Data {
        var request = URLRequest(url: Self.endpoint(for: provider))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

public enum StatusPageNormalizer {
    public static func normalize(_ data: Data) throws -> ProviderServiceStatus {
        let response = try JSONDecoder().decode(Response.self, from: data)
        // Statuspage rolls every component, including ones the user never
        // touches (e.g. OpenAI's FedRAMP environment), into the top-level
        // indicator. Only major and critical mean a real outage worth
        // surfacing; none, minor, and maintenance are treated as operational.
        switch response.status.indicator {
        case "major", "critical":
            return .incident(response.status.description ?? "Service incident")
        default:
            return .operational
        }
    }

    private struct Response: Decodable {
        let status: Status
    }

    private struct Status: Decodable {
        let indicator: String
        let description: String?
    }
}
