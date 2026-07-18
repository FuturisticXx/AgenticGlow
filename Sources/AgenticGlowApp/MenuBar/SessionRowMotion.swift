import AgenticGlowCore

/// Pure decision logic for the row's live-activity indicator: whether the
/// status glyph should breathe. Kept separate from SessionRowView so it is
/// unit-testable without SwiftUI, matching PermissionDissolve's pattern of
/// isolating timing/state decisions from view rendering.
enum SessionRowMotion {
    static let detailOffset: Double = -6
    static let standardDetailToggleDuration: Double = 0.2
    static let reducedMotionDetailToggleDuration: Double = 0.12
    static let collapsedChevronRotation: Double = 0
    static let expandedChevronRotation: Double = 180

    static func shouldPulse(phase: SessionPhase, reduceMotion: Bool) -> Bool {
        !reduceMotion && phase.isActive
    }

    static func detailToggleDuration(reduceMotion: Bool) -> Double {
        reduceMotion ? reducedMotionDetailToggleDuration : standardDetailToggleDuration
    }

    static func chevronRotation(isExpanded: Bool) -> Double {
        isExpanded ? expandedChevronRotation : collapsedChevronRotation
    }
}
