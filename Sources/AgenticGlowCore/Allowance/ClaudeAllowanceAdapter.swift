import Foundation

public protocol ClaudeUsageRequesting: Sendable {
    func fetchUsage(sessionCookie: String) async throws -> Data
}

public struct ClaudeAllowanceAdapter: AllowanceProviding {
    public let provider = AgentProvider.claude
    private let sessionCookie: @Sendable () throws -> String
    private let requester: any ClaudeUsageRequesting
    private let now: @Sendable () -> Date

    public init(
        sessionCookie: @escaping @Sendable () throws -> String,
        requester: any ClaudeUsageRequesting = ClaudeWebUsageClient(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sessionCookie = sessionCookie
        self.requester = requester
        self.now = now
    }

    public func fetch() async throws -> ProviderAllowance {
        let cookie = try sessionCookie()
        guard !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AllowanceAdapterError.unavailable(
                "Add a Claude session cookie in Usage Access."
            )
        }
        let data = try await requester.fetchUsage(sessionCookie: cookie)
        do {
            return try ClaudeAllowanceNormalizer.normalize(data, fetchedAt: now())
        } catch let error as AllowanceAdapterError {
            throw error
        } catch {
            throw AllowanceAdapterError.invalidResponse
        }
    }
}

public struct ClaudeWebUsageClient: ClaudeUsageRequesting {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchUsage(sessionCookie: String) async throws -> Data {
        let request = try Self.makeRequest(sessionCookie: sessionCookie)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AllowanceAdapterError.unavailable("Claude usage is temporarily unavailable.")
        }
        try Self.validate(statusCode: http.statusCode)
        return data
    }

    public static func makeRequest(sessionCookie: String) throws -> URLRequest {
        let organization = try activeOrganization(in: sessionCookie)
        guard let url = URL(
            string: "https://claude.ai/api/organizations/\(organization)/usage"
        ) else {
            throw AllowanceAdapterError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.timeoutInterval = 15
        return request
    }

    public static func validate(statusCode: Int) throws {
        switch statusCode {
        case 200 ..< 300:
            return
        case 401, 403:
            throw AllowanceAdapterError.unavailable(
                "Claude session cookie expired. Update Usage Access."
            )
        case 429:
            throw AllowanceAdapterError.rateLimited(retryAfter: nil)
        default:
            throw AllowanceAdapterError.unavailable("Claude usage is temporarily unavailable.")
        }
    }

    private static func activeOrganization(in cookie: String) throws -> String {
        for field in cookie.split(separator: ";") {
            let pair = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2,
                  pair[0].trimmingCharacters(in: .whitespaces) == "lastActiveOrg"
            else { continue }
            let value = pair[1]
                .removingPercentEncoding?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
            if !value.isEmpty { return value }
        }
        throw AllowanceAdapterError.unavailable(
            "Claude session cookie is missing its active organization."
        )
    }
}

public enum ClaudeAllowanceNormalizer {
    public static func normalize(_ data: Data, fetchedAt: Date) throws -> ProviderAllowance {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return ProviderAllowance(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentUsed: response.fiveHour.utilization,
            currentResetAt: parseDate(response.fiveHour.resetsAt),
            weeklyPercentUsed: response.sevenDay?.utilization,
            weeklyResetAt: response.sevenDay.flatMap { parseDate($0.resetsAt) },
            fetchedAt: fetchedAt
        )
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private struct Response: Decodable {
        let fiveHour: Window
        let sevenDay: Window?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    private struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }
}
