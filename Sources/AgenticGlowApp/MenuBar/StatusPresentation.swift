import AppKit
import AgenticGlowCore

struct StatusPresentation: Equatable {
    let symbolName: String
    let title: String
    let accessibilityLabel: String
    let color: NSColor
    let animates: Bool

    init(resolved: ResolvedSessions, showTimer: Bool, reduceMotion: Bool) {
        switch resolved.dominantPhase {
        case .permission:
            symbolName = "exclamationmark.circle.fill"
            title = resolved.permissionCount > 1 ? "\(resolved.permissionCount)" : ""
            accessibilityLabel = resolved.permissionCount == 1
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
            accessibilityLabel = resolved.activeCount == 1
                ? "AgenticGlow, 1 active session"
                : "AgenticGlow, \(resolved.activeCount) active sessions"
            color = .controlAccentColor
            animates = !reduceMotion
        case .completed:
            symbolName = "checkmark.circle.fill"
            title = ""
            accessibilityLabel = "AgenticGlow, session completed"
            color = .systemGreen
            animates = false
        case .disconnected:
            symbolName = "bolt.slash.circle"
            title = ""
            accessibilityLabel = "AgenticGlow, integration disconnected"
            color = .secondaryLabelColor
            animates = false
        case .idle:
            symbolName = "circle.hexagongrid"
            title = ""
            accessibilityLabel = "AgenticGlow, idle"
            color = .labelColor
            animates = false
        }
    }

    private static func format(_ seconds: Int) -> String {
        seconds < 60 ? "<1m" : "\(seconds / 60)m"
    }
}
