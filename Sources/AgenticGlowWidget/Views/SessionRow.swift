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
    /// Cleared once synchronized state has gone stale: the elapsed count
    /// is the Mac's figure at observation, and showing it beside a
    /// "Thinking" label would claim a timer that is not running.
    var showsElapsed = true

    var body: some View {
        Link(destination: WidgetDeepLink.openSession(provider: session.provider, sessionID: session.sessionID).url) {
            HStack(spacing: 8) {
                Image(systemName: PhaseGlyph.symbolName(for: session.phase, toolCategory: session.toolCategory))
                    .foregroundStyle(PhaseGlyph.color(for: session.phase))
                    .frame(width: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.projectName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(detailText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if showsElapsed, session.phase.isActive,
                   let elapsed = WidgetSnapshotFormatting.elapsedLabel(seconds: session.elapsedSeconds) {
                    Text(elapsed)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.projectName), \(detailText)")
    }

    private var detailText: String {
        if let compactDetail = session.compactDetail {
            return compactDetail
        }
        switch style {
        case .compact:
            return PhaseGlyph.label(for: session.phase)
        case .detailed:
            return "\(PhaseGlyph.label(for: session.phase)) · \(session.provider.displayName)"
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
