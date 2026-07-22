import SwiftUI
import AgenticGlowCore

struct SessionRow: View {
    enum Style {
        case compact
        case detailed
    }

    let session: WidgetSessionSummary
    let now: Date
    let style: Style

    var body: some View {
        Link(destination: WidgetDeepLink.openSession(provider: session.provider, sessionID: session.sessionID).url) {
            HStack(spacing: 8) {
                Image(systemName: PhaseGlyph.symbolName(for: session.phase, toolCategory: session.toolCategory))
                    .foregroundStyle(PhaseGlyph.color(for: session.phase))
                    .frame(width: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.projectName)
                        .font(.caption.weight(.bold))
                        .fontWidth(.condensed)
                        .lineLimit(1)
                    Text(detailText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if session.phase.isActive, let elapsed = WidgetSnapshotFormatting.elapsedLabel(seconds: session.elapsedSeconds) {
                    Text(elapsed)
                        .font(.caption2.weight(.bold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.projectName), \(PhaseGlyph.label(for: session.phase))")
    }

    private var detailText: String {
        switch style {
        case .compact:
            PhaseGlyph.label(for: session.phase)
        case .detailed:
            "\(PhaseGlyph.label(for: session.phase)) · \(session.provider.displayName)"
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        SessionRow(session: SampleData.attentionSession, now: SampleData.now, style: .detailed)
        SessionRow(session: SampleData.editingSession, now: SampleData.now, style: .detailed)
        SessionRow(session: SampleData.failedSession, now: SampleData.now, style: .detailed)
    }
    .padding()
}
