import Foundation

/// What an allowance figure means once the window it described has ended.
///
/// A Mac states a percentage and the moment its window resets. Both are
/// true when observed. Carried to an iPhone that then loses contact with
/// that Mac, the percentage keeps being shown long after the window it
/// belongs to has ended. The 2026-09-21 capture is the case this exists
/// for: Codex at 84% and Claude at 57% under captions reading "resets in
/// Resetting", eleven hours after a snapshot whose five-hour windows had
/// by then rolled over twice. Both were in fact untouched, because the
/// Mac that would have spent them was asleep for all of it.
///
/// A window boundary is arithmetic, not an observation. Given the window
/// a reset belongs to and how long that window runs, a boundary in the
/// past names every later boundary without asking anyone. That is all
/// this type does: no I/O, no clock of its own, `now` passed in.
///
/// Deliberately not applied on the desktop. There the snapshot is seconds
/// old and a reset in the past really is a reset in progress, which is
/// what `WidgetSnapshotFormatting.relativeResetLabel` already says.
public enum AllowanceWindowRollover {
    /// The period of every provider's weekly window. Codex and Claude
    /// both meter theirs on a fixed seven-day cycle.
    public static let weeklyDuration: TimeInterval = 7 * 24 * 60 * 60

    /// Claude publishes no window length of its own, and its primary
    /// window is a documented five hours. Codex states its own in
    /// `windowDurationMins` and is never assumed.
    public static let claudeCurrentDuration: TimeInterval = 5 * 60 * 60

    /// Refuses a period count large enough to mean the inputs are junk
    /// rather than old. A decade of five-hour windows is about 17,500, so
    /// this rejects a corrupt date without touching any real gap.
    static let maximumPeriods: Double = 1_000_000

    public struct Result: Equatable, Sendable {
        /// The percentage to show: untouched while the window is still
        /// running, 100 once it has ended. Stays nil when the provider
        /// reported no figure, because a window resetting is not a reason
        /// to invent one it never gave.
        public let percentLeft: Double?
        /// The boundary a caption should name: the observed one while it
        /// is still ahead, otherwise the next one after `now`. Nil when
        /// the window has ended and its period is unknown, which is
        /// honest: something reset, and we cannot say when the next one
        /// lands.
        public let resetAt: Date?
        /// Whether `percentLeft` was derived rather than observed, so the
        /// caller can mark it and it is never mistaken for a figure the
        /// Mac actually reported.
        public let isDerived: Bool

        public init(percentLeft: Double?, resetAt: Date?, isDerived: Bool) {
            self.percentLeft = percentLeft
            self.resetAt = resetAt
            self.isDerived = isDerived
        }
    }

    /// Re-reads one window's figures as of `now`.
    ///
    /// `duration` is the window's period, not its remaining time: five
    /// hours for a 5h window however far into it the observation was.
    public static func apply(
        percentLeft: Double?,
        resetAt: Date?,
        duration: TimeInterval?,
        now: Date
    ) -> Result {
        // No stated boundary, so nothing can be said to have elapsed.
        guard let resetAt else {
            return Result(percentLeft: percentLeft, resetAt: nil, isDerived: false)
        }
        // Still ahead: the observation stands exactly as it was made.
        guard resetAt <= now else {
            return Result(percentLeft: percentLeft, resetAt: resetAt, isDerived: false)
        }
        let next = duration.flatMap { nextBoundary(after: resetAt, duration: $0, now: now) }
        // The window ended, but the provider never gave a figure for it.
        // Correcting the boundary is still right; claiming a percentage
        // would be inventing one.
        guard percentLeft != nil else {
            return Result(percentLeft: nil, resetAt: next, isDerived: false)
        }
        return Result(percentLeft: 100, resetAt: next, isDerived: true)
    }

    /// The first boundary strictly after `now`, advancing from a reset
    /// that has already passed.
    ///
    /// Computed in whole periods rather than by stepping, so a window
    /// that lapsed over a long weekend costs the same as one that lapsed
    /// an hour ago.
    static func nextBoundary(after resetAt: Date, duration: TimeInterval, now: Date) -> Date? {
        guard duration.isFinite, duration > 0 else { return nil }
        let elapsed = now.timeIntervalSince(resetAt)
        guard elapsed.isFinite, elapsed >= 0 else { return nil }
        // Strictly after: a `now` sitting exactly on a boundary belongs to
        // the window that boundary opened, not the one it closed.
        let periods = (elapsed / duration).rounded(.down) + 1
        guard periods.isFinite, periods <= maximumPeriods else { return nil }
        return resetAt.addingTimeInterval(periods * duration)
    }
}
