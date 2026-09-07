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
    /// Also the point at which a session still claiming an active phase is
    /// treated as stale: with no event for this long, "still thinking" is no
    /// longer credible evidence of current work. One threshold, so a session
    /// never lingers in the count after it stops being shown.
    public static let idleVisibilityWindow: TimeInterval = 10 * 60

    /// Phases that stay visible however old their last event is.
    ///
    /// Active phases are only reachable inside the window, because the
    /// resolver demotes a stale active session to `.idle` at the same cutoff.
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
