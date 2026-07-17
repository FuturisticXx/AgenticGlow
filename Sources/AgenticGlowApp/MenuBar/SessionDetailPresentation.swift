import Foundation
import AgenticGlowCore

/// Content for the row's expanded tier: reached by tapping the disclosure
/// button, not shown by default. Built entirely from fields SessionSnapshot
/// already carries (surface, updatedAt) plus the label already used for the
/// compact row, so no new data capture is required.
struct SessionDetail: Equatable {
    let currentStep: String
    let lastUpdated: String
    let surface: String
    let note: String?
}

enum SessionDetailPresentation {
    static func detail(for session: SessionSnapshot, now: Date) -> SessionDetail {
        SessionDetail(
            currentStep: session.label,
            lastUpdated: relativeTime(from: session.updatedAt, to: now),
            surface: session.surface.displayName,
            note: session.phase == .failed ? Self.failedNote : nil
        )
    }

    /// AgenticGlow infers "failed" from a mid-task disconnect; it has no
    /// error message or exit code from the agent itself, so the copy says
    /// only what is actually known.
    private static let failedNote =
        "Stopped while working. AgenticGlow doesn't receive an error reason, this is inferred from the session disconnecting before it finished."

    private static func relativeTime(from date: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 5 { return "just now" }
        switch DurationTier(seconds: seconds) {
        case .seconds(let s): return "\(s)s ago"
        case .minutes(let m, _): return "\(m)m ago"
        case .hours(let h, _): return "\(h)h ago"
        }
    }
}
