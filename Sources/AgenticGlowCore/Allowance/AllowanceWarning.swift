import Foundation

/// Shared low-allowance signal used by the menu bar badge and quota
/// notifications so both surfaces always agree on what "running low" means.
public enum AllowanceWarning {
    public static let thresholdPercentLeft: Double = 10

    public struct Window: Equatable, Sendable {
        public let label: String
        public let percentLeft: Double
        public let resetAt: Date?

        public init(label: String, percentLeft: Double, resetAt: Date?) {
            self.label = label
            self.percentLeft = percentLeft
            self.resetAt = resetAt
        }
    }

    /// Every allowance a provider currently reports a number for, in
    /// display order. The single place that knows a provider is either
    /// pool-based or window-based, so warnings, notifications, and the
    /// popover continuation line all agree without repeating the rule.
    /// A pool or window with no value is omitted rather than treated as
    /// zero, since "unknown" is not "exhausted".
    public static func windows(in allowance: ProviderAllowance) -> [Window] {
        guard allowance.pools.isEmpty else {
            return allowance.pools.compactMap { pool in
                pool.percentLeft.map {
                    Window(label: pool.label, percentLeft: $0, resetAt: pool.resetAt)
                }
            }
        }
        var windows: [Window] = []
        if let left = allowance.currentPercentLeft {
            windows.append(Window(
                label: allowance.currentWindowLabel,
                percentLeft: left,
                resetAt: allowance.currentResetAt
            ))
        }
        if let left = allowance.weeklyPercentLeft {
            windows.append(Window(
                label: "week",
                percentLeft: left,
                resetAt: allowance.weeklyResetAt
            ))
        }
        return windows
    }

    public static func lowWindows(in allowance: ProviderAllowance) -> [Window] {
        windows(in: allowance).filter { $0.percentLeft < thresholdPercentLeft }
    }
}
