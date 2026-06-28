import AppKit
import KlarityCore

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
                ? "Klarity, 1 session needs permission"
                : "Klarity, \(resolved.permissionCount) sessions need permission"
            color = .systemYellow
            animates = false
        case .usingTool, .thinking:
            symbolName = "sparkle"
            let workingSession = resolved.sessions.first {
                [.usingTool, .thinking].contains($0.phase)
            }
            let timer = showTimer ? workingSession?.elapsedSeconds.map(Self.format) : nil
            let count = resolved.activeCount > 1 ? "\(resolved.activeCount)" : nil
            title = [count, timer].compactMap { $0 }.joined(separator: " · ")
            accessibilityLabel = resolved.activeCount == 1
                ? "Klarity, 1 active session"
                : "Klarity, \(resolved.activeCount) active sessions"
            color = .controlAccentColor
            animates = !reduceMotion
        case .completed:
            symbolName = "checkmark.circle.fill"
            title = ""
            accessibilityLabel = "Klarity, session completed"
            color = .systemGreen
            animates = false
        case .disconnected:
            symbolName = "bolt.slash.circle"
            title = ""
            accessibilityLabel = "Klarity, integration disconnected"
            color = .secondaryLabelColor
            animates = false
        case .idle:
            symbolName = "circle.hexagongrid"
            title = ""
            accessibilityLabel = "Klarity, idle"
            color = .labelColor
            animates = false
        }
    }

    private static func format(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
}
