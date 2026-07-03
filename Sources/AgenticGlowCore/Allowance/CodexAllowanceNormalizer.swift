import Foundation

public enum CodexAllowanceNormalizer {
    public static func normalize(_ data: Data, fetchedAt: Date) throws -> ProviderAllowance {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let limits = response.result.rateLimits
        return ProviderAllowance(
            provider: .codex,
            currentWindowLabel: limits.primary.windowDurationMins == 300 ? "5h" : "Current",
            currentPercentUsed: limits.primary.usedPercent,
            currentResetAt: Date(timeIntervalSince1970: limits.primary.resetsAt),
            weeklyPercentUsed: limits.secondary?.usedPercent,
            weeklyResetAt: limits.secondary.map { Date(timeIntervalSince1970: $0.resetsAt) },
            fetchedAt: fetchedAt
        )
    }
}

private extension CodexAllowanceNormalizer {
    struct Response: Decodable {
        let result: Result
    }

    struct Result: Decodable {
        let rateLimits: RateLimits
    }

    struct RateLimits: Decodable {
        let primary: Window
        let secondary: Window?
    }

    struct Window: Decodable {
        let usedPercent: Double
        let windowDurationMins: Int
        let resetsAt: TimeInterval
    }
}
