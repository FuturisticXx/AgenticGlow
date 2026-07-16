import AppKit
import AgenticGlowCore

struct StatusPresentation: Equatable {
    let symbolName: String
    let title: String
    let accessibilityLabel: String
    let color: NSColor
    let animates: Bool
    let showsAllowanceBadge: Bool
    /// Providers coloring the working icon, in a stable Claude-then-Codex
    /// order. Empty unless the dominant state is thinking or using a tool:
    /// one entry drives a solid tint, two entries drive the cross-fade. The
    /// controller resolves actual colors per menu bar appearance at render
    /// time, so the icon can adapt when the wallpaper flips the bar.
    let activeProviders: [AgentProvider]
    /// True when a session awaits permission while at least one other session
    /// works and Reduce Motion is off: the controller alternates the icon
    /// between the working hexagon and the yellow exclamation.
    let pulsesPermission: Bool

    init(
        resolved: ResolvedSessions,
        showTimer: Bool,
        reduceMotion: Bool,
        lowAllowance: Bool = false
    ) {
        showsAllowanceBadge = lowAllowance
        let phaseLabel: String
        switch resolved.dominantPhase {
        case .permission:
            symbolName = SessionPhasePresentation.symbolName(for: .permission, in: .menuBar)
            title = resolved.permissionCount > 1 ? "\(resolved.permissionCount)" : ""
            let workingCount = resolved.activeCount - resolved.permissionCount
            var label = resolved.permissionCount == 1
                ? "AgenticGlow, 1 session needs permission"
                : "AgenticGlow, \(resolved.permissionCount) sessions need permission"
            if workingCount == 1 {
                label += ", 1 active session"
            } else if workingCount > 1 {
                label += ", \(workingCount) active sessions"
            }
            phaseLabel = label
            color = SessionPhasePresentation.nsColor(for: .permission)
            animates = workingCount > 0 && !reduceMotion
        case .usingTool, .thinking:
            symbolName = SessionPhasePresentation.symbolName(for: resolved.dominantPhase, in: .menuBar)
            let workingSession = resolved.sessions.first {
                [.usingTool, .thinking].contains($0.phase)
            }
            let timer = showTimer ? workingSession?.elapsedSeconds.map(Self.format) : nil
            let count = resolved.activeCount > 1 ? "\(resolved.activeCount)" : nil
            title = [count, timer].compactMap { $0 }.joined(separator: " · ")
            phaseLabel = resolved.activeCount == 1
                ? "AgenticGlow, 1 active session"
                : "AgenticGlow, \(resolved.activeCount) active sessions"
            color = SessionPhasePresentation.nsColor(for: resolved.dominantPhase)
            animates = !reduceMotion
        case .completed:
            symbolName = SessionPhasePresentation.symbolName(for: .completed, in: .menuBar)
            title = ""
            phaseLabel = "AgenticGlow, session completed"
            color = SessionPhasePresentation.nsColor(for: .completed)
            animates = false
        case .disconnected:
            symbolName = SessionPhasePresentation.symbolName(for: .disconnected, in: .menuBar)
            title = ""
            phaseLabel = "AgenticGlow, integration disconnected"
            color = SessionPhasePresentation.nsColor(for: .disconnected)
            animates = false
        case .failed:
            symbolName = SessionPhasePresentation.symbolName(for: .failed, in: .menuBar)
            title = ""
            phaseLabel = "AgenticGlow, session stopped unexpectedly"
            color = SessionPhasePresentation.nsColor(for: .failed)
            animates = false
        case .idle:
            symbolName = SessionPhasePresentation.symbolName(for: .idle, in: .menuBar)
            title = ""
            phaseLabel = "AgenticGlow, idle"
            color = SessionPhasePresentation.nsColor(for: .idle)
            animates = false
        }
        let workingProviders = [AgentProvider.claude, .codex].filter {
            resolved.activeProviders.contains($0)
        }
        let working = [SessionPhase.thinking, .usingTool].contains(resolved.dominantPhase)
        pulsesPermission = resolved.dominantPhase == .permission
            && !workingProviders.isEmpty
            && !reduceMotion
        activeProviders = working || pulsesPermission ? workingProviders : []

        accessibilityLabel = lowAllowance ? "\(phaseLabel), usage low" : phaseLabel
    }

    private static func format(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3_600 { return "\(seconds / 60)m" }
        let minutes = (seconds % 3_600) / 60
        return minutes == 0 ? "\(seconds / 3_600)h" : "\(seconds / 3_600)h \(minutes)m"
    }
}
