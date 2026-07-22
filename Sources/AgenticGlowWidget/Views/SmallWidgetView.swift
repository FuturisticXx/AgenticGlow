import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Small's job: one glance, one number. Priority: attention needed >
/// active sessions > lowest allowance remaining > calm idle state.
struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot
    let now: Date

    private var freshness: WidgetDataFreshness {
        WidgetDataFreshness.evaluate(generatedAt: snapshot.generatedAt, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headline
            Spacer(minLength: 0)
            footer
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var headline: some View {
        if snapshot.attentionCount > 0 {
            glyph("exclamationmark.circle.fill", color: .yellow)
            Text(snapshot.attentionCount == 1 ? "1 session" : "\(snapshot.attentionCount) sessions")
                .font(.caption.weight(.bold))
                .fontWidth(.condensed)
            Text("needs you")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        } else if snapshot.activeCount > 0 {
            glyph("sparkle", color: .accentColor)
            Text(snapshot.activeCount == 1 ? "1 session" : "\(snapshot.activeCount) sessions")
                .font(.caption.weight(.bold))
                .fontWidth(.condensed)
            Text("active")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        } else if let lowest = lowestAllowance {
            glyph("gauge.with.dots.needle.33percent", color: WidgetColorPalette.color(for: lowest.provider))
            Text(WidgetSnapshotFormatting.percentLeftLabel(lowest.currentPercentLeft))
                .font(.caption.weight(.bold))
                .fontWidth(.condensed)
                .monospacedDigit()
            Text(lowest.provider.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        } else {
            glyph("checkmark.circle", color: .secondary)
            Text("All quiet")
                .font(.caption.weight(.bold))
                .fontWidth(.condensed)
        }
    }

    private func glyph(_ systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private var lowestAllowance: WidgetAllowanceSummary? {
        snapshot.allowances.min { ($0.currentPercentLeft ?? 100) < ($1.currentPercentLeft ?? 100) }
    }

    private var footer: some View {
        Group {
            if freshness == .stale {
                Label("Stale", systemImage: "clock.arrow.circlepath")
            } else {
                Text(WidgetSnapshotFormatting.lastUpdatedLabel(snapshot.generatedAt, now: now))
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
    }
}

#Preview("Attention", as: .systemSmall) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.attentionOnlySnapshot)))
}

#Preview("Active", as: .systemSmall) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.busySnapshot)))
}

#Preview("Low allowance", as: .systemSmall) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.lowAllowanceSnapshot)))
}

#Preview("All quiet", as: .systemSmall) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.idleSnapshot)))
}

#Preview("Stale", as: .systemSmall) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(
        date: SampleData.now,
        state: .result(.loaded(SampleData.staleSnapshot))
    )
}
