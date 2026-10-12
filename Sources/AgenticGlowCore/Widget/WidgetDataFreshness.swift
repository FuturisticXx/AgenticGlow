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

    /// How long a timeline may go before the widget asks for another,
    /// when nothing sooner is due.
    public static let fallbackRefreshInterval: TimeInterval = 15 * 60

    /// The moments after `now` at which an allowance on the canvas turns
    /// stale, earliest first. One second past the threshold, because a
    /// reading exactly at it still evaluates as fresh. A timeline entry at
    /// each lets the "Updated" label appear on time without waiting for
    /// a reload WidgetKit may not grant.
    public static func allowanceStaleTransitions(in result: WidgetSnapshotLoadResult, after now: Date) -> [Date] {
        guard case let .loaded(snapshot) = result else { return [] }
        return Set(snapshot.allowances.map { $0.fetchedAt.addingTimeInterval(staleThreshold + 1) })
            .filter { $0 > now }
            .sorted()
    }

    /// When the timeline should ask for new data: at the first allowance
    /// turning stale, so the widget reads the app's newer observation if
    /// there is one, otherwise after the fallback interval.
    public static func nextTimelineRefresh(for result: WidgetSnapshotLoadResult, now: Date) -> Date {
        let fallback = now.addingTimeInterval(fallbackRefreshInterval)
        guard let first = allowanceStaleTransitions(in: result, after: now).first else { return fallback }
        return min(first, fallback)
    }
}
