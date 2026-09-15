import Foundation

public enum WidgetDataFreshness: Equatable, Sendable {
    case fresh
    case stale

    /// Snapshots older than this are presented as stale rather than current.
    /// Set above the app's own idle allowance refresh interval (5 minutes,
    /// AllowanceRefreshPolicy.idleInterval) so a normal idle gap between app
    /// refreshes doesn't falsely read as stale.
    public static let staleThreshold: TimeInterval = 15 * 60

    public static func evaluate(generatedAt: Date, now: Date) -> WidgetDataFreshness {
        now.timeIntervalSince(generatedAt) > staleThreshold ? .stale : .fresh
    }
}
