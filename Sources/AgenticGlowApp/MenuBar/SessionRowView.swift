import AgenticGlowCore
import SwiftUI

struct SessionRowView: View {
    let session: SessionSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.projectName)
                        .font(.body.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let elapsed = session.elapsedSeconds,
                   [.thinking, .usingTool].contains(session.phase) {
                    Text(Self.format(elapsed))
                        .monospacedDigit()
                        .font(.caption)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("AgenticGlow.Session.\(session.id)")
        .accessibilityLabel(Self.accessibilityLabel(for: session))
        .accessibilityHint("Activates the source application")
    }

    private var detail: String {
        "\(session.label) · \(session.surface.displayName)"
    }

    private var icon: String {
        switch session.phase {
        case .permission: "exclamationmark.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .disconnected: "bolt.slash.circle"
        case .idle: "circle"
        case .thinking, .usingTool: "sparkle"
        }
    }

    private var color: Color {
        switch session.phase {
        case .permission: Color(nsColor: .systemYellow)
        case .completed: Color(nsColor: .systemGreen)
        case .disconnected: .secondary
        case .idle: .primary
        case .thinking, .usingTool: ProviderColor.color(for: session.provider)
        }
    }

    static func accessibilityLabel(for session: SessionSnapshot) -> String {
        "\(session.provider.displayName), \(session.projectName), \(session.label), \(session.surface.displayName)"
    }

    /// Seconds drop out at the hour scale so long-running rows stay calm.
    static func format(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3_600 { return "\(seconds / 60)m \(seconds % 60)s" }
        let minutes = (seconds % 3_600) / 60
        return minutes == 0 ? "\(seconds / 3_600)h" : "\(seconds / 3_600)h \(minutes)m"
    }
}

private extension AgentProvider {
    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        }
    }
}

private extension SourceSurface {
    var displayName: String {
        switch self {
        case .cli: "CLI"
        case .desktop: "Desktop"
        case .unknown: "Unknown source"
        }
    }
}
