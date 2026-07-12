import Foundation

/// Pure decision logic for user notifications. Delivery lives in the app
/// layer; this layer only decides what is newly worth announcing.
public enum NotificationPolicy {
    /// Sessions that entered the permission phase since the previous refresh.
    public static func newlyAwaitingPermission(
        previousPhases: [String: SessionPhase],
        sessions: [SessionSnapshot]
    ) -> [SessionSnapshot] {
        sessions.filter { session in
            session.phase == .permission && previousPhases[session.id] != .permission
        }
    }
}

public struct QuotaAlert: Equatable, Sendable {
    public enum Level: Equatable, Sendable {
        case low
        case exhausted
    }

    public let level: Level
    public let window: AllowanceWarning.Window
}

/// Announces meaningful allowance transitions and stays silent while a
/// provider window remains low or exhausted.
public struct QuotaAlertTracker: Sendable {
    private struct Key: Hashable, Sendable {
        let provider: AgentProvider
        let windowLabel: String
    }

    private var states: [Key: QuotaAlert.Level] = [:]

    public init() {}

    public mutating func newAlerts(
        provider: AgentProvider,
        allowance: ProviderAllowance
    ) -> [QuotaAlert] {
        observations(in: allowance).compactMap { window in
            let key = Key(provider: provider, windowLabel: window.label)
            guard window.percentLeft < AllowanceWarning.thresholdPercentLeft else {
                states.removeValue(forKey: key)
                return nil
            }

            let current: QuotaAlert.Level = window.percentLeft <= 0 ? .exhausted : .low
            let previous = states[key]
            if previous == .exhausted { return nil }
            states[key] = current
            if previous == current { return nil }
            return QuotaAlert(level: current, window: window)
        }
    }

    private func observations(in allowance: ProviderAllowance) -> [AllowanceWarning.Window] {
        var windows: [AllowanceWarning.Window] = []
        if let left = allowance.currentPercentLeft {
            windows.append(AllowanceWarning.Window(
                label: allowance.currentWindowLabel,
                percentLeft: left,
                resetAt: allowance.currentResetAt
            ))
        }
        if let left = allowance.weeklyPercentLeft {
            windows.append(AllowanceWarning.Window(
                label: "week",
                percentLeft: left,
                resetAt: allowance.weeklyResetAt
            ))
        }
        return windows
    }
}
