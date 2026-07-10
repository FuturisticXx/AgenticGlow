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
            symbolName = "exclamationmark.circle.fill"
            title = resolved.permissionCount > 1 ? "\(resolved.permissionCount)" : ""
            phaseLabel = resolved.permissionCount == 1
                ? "AgenticGlow, 1 session needs permission"
                : "AgenticGlow, \(resolved.permissionCount) sessions need permission"
            color = .systemYellow
            animates = false
        case .usingTool, .thinking:
            symbolName = "circle.hexagongrid"
            let workingSession = resolved.sessions.first {
                [.usingTool, .thinking].contains($0.phase)
            }
            let timer = showTimer ? workingSession?.elapsedSeconds.map(Self.format) : nil
            let count = resolved.activeCount > 1 ? "\(resolved.activeCount)" : nil
            title = [count, timer].compactMap { $0 }.joined(separator: " · ")
            phaseLabel = resolved.activeCount == 1
                ? "AgenticGlow, 1 active session"
                : "AgenticGlow, \(resolved.activeCount) active sessions"
            color = .controlAccentColor
            animates = !reduceMotion
        case .completed:
            symbolName = "checkmark.circle.fill"
            title = ""
            phaseLabel = "AgenticGlow, session completed"
            color = .systemGreen
            animates = false
        case .disconnected:
            symbolName = "bolt.slash.circle"
            title = ""
            phaseLabel = "AgenticGlow, integration disconnected"
            color = .secondaryLabelColor
            animates = false
        case .idle:
            symbolName = "circle.hexagongrid"
            title = ""
            phaseLabel = "AgenticGlow, idle"
            color = .labelColor
            animates = false
        }
        let working = [SessionPhase.thinking, .usingTool].contains(resolved.dominantPhase)
        activeProviders = working
            ? [.claude, .codex].filter { resolved.activeProviders.contains($0) }
            : []

        accessibilityLabel = lowAllowance ? "\(phaseLabel), usage low" : phaseLabel
    }

    private static func format(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m"
    }
}
