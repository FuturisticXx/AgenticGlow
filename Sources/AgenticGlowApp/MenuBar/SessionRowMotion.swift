import AgenticGlowCore

/// Pure decision logic for the row's live-activity indicator: whether the
/// status glyph should breathe. Kept separate from SessionRowView so it is
/// unit-testable without SwiftUI, matching PermissionDissolve's pattern of
/// isolating timing/state decisions from view rendering.
enum SessionRowMotion {
    static func shouldPulse(phase: SessionPhase, reduceMotion: Bool) -> Bool {
        !reduceMotion && [.thinking, .usingTool].contains(phase)
    }
}
