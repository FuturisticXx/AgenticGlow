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

/// Deduplicates low-allowance alerts so each provider window fires at most
/// once per app run per reset period.
public struct QuotaAlertTracker: Sendable {
    private var fired: Set<String> = []

    public init() {}

    public mutating func newAlerts(
        provider: AgentProvider,
        allowance: ProviderAllowance
    ) -> [AllowanceWarning.Window] {
        AllowanceWarning.lowWindows(in: allowance).filter { window in
            let key = [
                provider.rawValue,
                window.label,
                window.resetAt.map { String($0.timeIntervalSince1970) } ?? "-"
            ].joined(separator: "|")
            return fired.insert(key).inserted
        }
    }
}
