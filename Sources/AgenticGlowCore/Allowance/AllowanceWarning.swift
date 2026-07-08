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

    public static func lowWindows(in allowance: ProviderAllowance) -> [Window] {
        var windows: [Window] = []
        if let left = allowance.currentPercentLeft, left < thresholdPercentLeft {
            windows.append(Window(
                label: allowance.currentWindowLabel,
                percentLeft: left,
                resetAt: allowance.currentResetAt
            ))
        }
        if let left = allowance.weeklyPercentLeft, left < thresholdPercentLeft {
            windows.append(Window(
                label: "week",
                percentLeft: left,
                resetAt: allowance.weeklyResetAt
            ))
        }
        return windows
    }
}
