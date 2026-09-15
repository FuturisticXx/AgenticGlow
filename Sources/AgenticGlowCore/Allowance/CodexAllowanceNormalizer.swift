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

    /// A reset further out than this is a unit slip or a garbage value, not
    /// a real window. Codex windows are hours to a week, so a year is
    /// generous while still rejecting values the date formatters would
    /// otherwise render as a date centuries away.
    static let maximumResetHorizon: TimeInterval = 365 * 24 * 60 * 60

    /// Drops the reset rather than the whole allowance: the percentages are
    /// still worth showing when only the timestamp is unusable.
    static func resetDate(_ seconds: TimeInterval, fetchedAt: Date) -> Date? {
        guard seconds.isFinite else { return nil }
        let date = Date(timeIntervalSince1970: seconds)
        guard abs(date.timeIntervalSince(fetchedAt)) <= maximumResetHorizon else { return nil }
        return date
    }

    public static func normalize(_ data: Data, fetchedAt: Date) throws -> ProviderAllowance {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let limits = response.result.rateLimits
        return ProviderAllowance(
            provider: .codex,
            currentWindowLabel: Self.label(forMinutes: limits.primary.windowDurationMins),
            currentPercentUsed: limits.primary.usedPercent,
            currentResetAt: Self.resetDate(limits.primary.resetsAt, fetchedAt: fetchedAt),
            weeklyPercentUsed: limits.secondary?.usedPercent,
            weeklyResetAt: limits.secondary.flatMap { Self.resetDate($0.resetsAt, fetchedAt: fetchedAt) },
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
