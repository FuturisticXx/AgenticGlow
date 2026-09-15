import Foundation

/// Decides whether a resolved session still belongs on a surface whose
/// semantics are "active right now": the menu bar count, the popover rows,
/// work groups, model summaries, and the widget.
///
/// This is a visibility policy, not cleanup. Nothing here removes a session
/// file, forgets a session identity, or marks a session terminated. A hidden
/// session is still merged, deduplicated, and ownership-ranked, and it
/// reappears on its own the moment a newer event arrives.
public enum SessionVisibilityPolicy {
    /// How long a session with no meaningful activity stays visible.
    ///
    /// Also the point at which a session still claiming to think is treated
    /// as stale: with no event for this long, "still thinking" is no longer
    /// credible evidence of current work.
    public static let idleVisibilityWindow: TimeInterval = 10 * 60

    /// The same allowance for a session whose last event started a tool.
    ///
    /// A `PreToolUse` with no matching `PostToolUse` and a live process is
    /// real evidence of work in progress, unlike silence after a tool
    /// finished, so a long build or test run is not mistaken for a dead
    /// session. Bounded rather than unlimited: a tool call still running an
    /// hour later is far more likely to be a session that died holding the
    /// phase than one genuinely mid-tool.
    public static let toolVisibilityWindow: TimeInterval = 60 * 60

    /// How long a session reporting `phase` may go without a new event
    /// before it stops counting as working. The single place the two
    /// windows are chosen between.
    public static func activityWindow(for phase: SessionPhase) -> TimeInterval {
        phase == .usingTool ? toolVisibilityWindow : idleVisibilityWindow
    }

    /// Phases that stay visible however old their last event is.
    ///
    /// Active phases are only reachable inside their own window, because the
    /// resolver demotes a stale active session to `.idle` at that cutoff.
    /// `.permission` is the deliberate exemption: a session waiting on the
    /// user consumes no tokens and runs no tools, so age is not evidence
    /// that it stopped needing an answer.
    public static func requiresAttention(_ phase: SessionPhase) -> Bool {
        phase.isActive || phase == .permission
    }

    /// - Parameter lastMeaningfulActivityAt: the newest genuine signal for
    ///   this session. That is the event's `updatedAt`, written only by a
    ///   provider hook or reported by an adapter as the thread's own update
    ///   time, or the moment the resolver first observed the source process
    ///   die. Polling, heartbeats, metadata refreshes, widget syncs, and
    ///   repeated resolution of an unchanged event are not activity and
    ///   never move it.
    public static func isVisible(
        phase: SessionPhase,
        lastMeaningfulActivityAt: Date,
        now: Date
    ) -> Bool {
        if requiresAttention(phase) { return true }
        // A negative interval means the clock moved backwards or the event
        // carries a future timestamp. Treat that as recent rather than
        // hiding a session on a timestamp anomaly.
        let idleFor = now.timeIntervalSince(lastMeaningfulActivityAt)
        return idleFor < idleVisibilityWindow
    }
}
