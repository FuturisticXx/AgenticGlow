import AgenticGlowCore
import SwiftUI

struct SessionRowView: View {
    let session: SessionSnapshot
    let action: () -> Void
    let onRemove: () -> Void

    @State private var isPulsing = false
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let accessibilityValue = Self.accessibilityValue(for: session)
        let row = Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .opacity(isPulsing ? 0.45 : 1)
                    .accessibilityHidden(true)
                    .onAppear(perform: updatePulse)
                    .onChange(of: SessionRowMotion.shouldPulse(phase: session.phase, reduceMotion: reduceMotion)) {
                        updatePulse()
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.projectName)
                        .font(.body.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let elapsed = session.elapsedSeconds, session.phase.isActive {
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
        .accessibilityValue(accessibilityValue ?? "")
        .accessibilityAddTraits(accessibilityValue != nil ? .updatesFrequently : [])
        .accessibilityHint("Activates the source application")

        let header = HStack(spacing: 4) {
            if isRemovable {
                row.contextMenu {
                    Button("Remove", systemImage: "xmark.circle", role: .destructive, action: onRemove)
                }
            } else {
                row
            }
            expandButton
        }

        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                detailPanel
            }
        }
    }

    private var expandButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("AgenticGlow.Session.\(session.id).Expand")
        .accessibilityLabel(isExpanded ? "Hide details" : "Show details")
    }

    private var detailPanel: some View {
        let fields = SessionDetailPresentation.detail(for: session, now: Date())
        return VStack(alignment: .leading, spacing: 3) {
            detailRow("Current step", fields.currentStep)
            detailRow("Surface", fields.surface)
            detailRow("Last updated", fields.lastUpdated)
            if let note = fields.note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 32)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
        .font(.caption2)
    }

    private var isRemovable: Bool {
        [.idle, .disconnected, .completed, .permission, .failed].contains(session.phase)
    }

    private func updatePulse() {
        let shouldPulse = SessionRowMotion.shouldPulse(phase: session.phase, reduceMotion: reduceMotion)
        guard shouldPulse != isPulsing else { return }
        if shouldPulse {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPulsing = false
            }
        }
    }

    private var detail: String {
        "\(session.label) · \(session.surface.displayName)"
    }

    private var icon: String {
        SessionPhasePresentation.symbolName(for: session.phase, toolCategory: session.toolCategory, in: .row)
    }

    private var color: Color {
        switch session.phase {
        case .thinking, .usingTool: ProviderColor.color(for: session.provider)
        default: SessionPhasePresentation.color(for: session.phase)
        }
    }

    /// `.failed` gets a distinct spoken suffix rather than a rewritten
    /// label, so VoiceOver users can tell a crashed session from one still
    /// working, without losing `session.label`'s last-action text (which
    /// the expanded detail panel also relies on).
    static func accessibilityLabel(for session: SessionSnapshot) -> String {
        let base = "\(session.provider.displayName), \(session.projectName), \(session.label), \(session.surface.displayName)"
        return session.phase == .failed ? "\(base), stopped while working" : base
    }

    /// Spoken elapsed time, kept out of the label itself (which stays
    /// stable) so VoiceOver doesn't re-announce the whole row every second.
    /// `.updatesFrequently` lets VoiceOver re-poll this value periodically
    /// while focus stays on the row, instead of never hearing it at all.
    static func accessibilityValue(for session: SessionSnapshot) -> String? {
        guard let elapsed = session.elapsedSeconds, session.phase.isActive else { return nil }
        return format(elapsed)
    }

    /// Seconds drop out at the hour scale so long-running rows stay calm.
    static func format(_ seconds: Int) -> String {
        switch DurationTier(seconds: seconds) {
        case .seconds(let s): return "\(s)s"
        case .minutes(let m, let s): return "\(m)m \(s)s"
        case .hours(let h, let m): return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
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

extension SourceSurface {
    var displayName: String {
        switch self {
        case .cli: "CLI"
        case .desktop: "Desktop"
        case .unknown: "Unknown source"
        }
    }
}
