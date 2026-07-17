import Foundation

public enum CodexAllowanceNormalizer {
    /// Codex usually reports a 5-hour primary window plus a weekly
    /// secondary one, but some accounts (observed live on a ChatGPT Plus
    /// plan, 2026-07-16) get only a weekly-scale primary window with no
    /// secondary at all. Label by known duration rather than assuming the
    /// primary window is always the 5-hour one.
    private static func label(forMinutes minutes: Int) -> String {
        switch minutes {
        case 300: "5h"
        case 10_080: "Weekly"
        default: "Current"
        }
    }

    public static func normalize(_ data: Data, fetchedAt: Date) throws -> ProviderAllowance {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let limits = response.result.rateLimits
        return ProviderAllowance(
            provider: .codex,
            currentWindowLabel: Self.label(forMinutes: limits.primary.windowDurationMins),
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
