import Foundation

public enum AllowanceAdapterError: Error, Equatable, Sendable {
    case unsupported(String)
    case unavailable(String)
    case invalidResponse
    case rateLimited(retryAfter: TimeInterval?)
}

public protocol AllowanceProviding: Sendable {
    var provider: AgentProvider { get }
    func fetch() async throws -> ProviderAllowance
}

public struct UnsupportedClaudeAllowanceAdapter: AllowanceProviding {
    public let provider = AgentProvider.claude

    public init() {}

    public func fetch() async throws -> ProviderAllowance {
        throw AllowanceAdapterError.unsupported(
            "Anthropic does not document a programmatic subscription-allowance endpoint."
        )
    }
}

public struct UnavailableAllowanceAdapter: AllowanceProviding {
    public let provider: AgentProvider
    private let reason: String

    public init(provider: AgentProvider, reason: String) {
        self.provider = provider
        self.reason = reason
    }

    public func fetch() async throws -> ProviderAllowance {
        throw AllowanceAdapterError.unavailable(reason)
    }
}

public enum AllowanceRefreshPolicy {
    public static let turnCompletionDebounce: TimeInterval = 4
    public static let workingInterval: TimeInterval = 60
    public static let popoverMaximumAge: TimeInterval = 15
    public static let idleInterval: TimeInterval = 300
    /// Cadence used while an exhausted window is due back. The idle
    /// interval would leave a reset unannounced for up to five minutes,
    /// which is the one moment the user is actually waiting on us.
    public static let resetWatchInterval: TimeInterval = 60
    /// How far ahead of an expected reset the closer watch starts. Kept
    /// short so a week-long exhaustion is not polled at a minute's cadence
    /// for days, which would waste provider requests for nothing.
    public static let resetWatchLeadTime: TimeInterval = 300

    /// True while a provider has an exhausted window whose usage could
    /// plausibly be back by now. A window with no reset time is always
    /// watched, since nothing tells us when to start looking.
    public static func isWatchingForReset(
        _ allowance: ProviderAllowance,
        now: Date
    ) -> Bool {
        let windows: [(left: Double?, reset: Date?)] = [
            (allowance.currentPercentLeft, allowance.currentResetAt),
            (allowance.weeklyPercentLeft, allowance.weeklyResetAt)
        ]
        return windows.contains { window in
            guard let left = window.left, left <= 0 else { return false }
            guard let reset = window.reset else { return true }
            return reset.timeIntervalSince(now) <= resetWatchLeadTime
        }
    }
}
