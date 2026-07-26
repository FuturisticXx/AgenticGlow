import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Small's job: one glance, one number. Priority: attention needed >
/// active sessions > lowest allowance remaining > calm idle state.
///
/// Attention stays at the top of that ladder while medium and large carry
/// no attention banner at all, and the difference is deliberate: here the
/// count is the widget's only content rather than a banner layered over
/// other content, so dropping it would report "3 sessions active" while
/// one of them sits blocked. It reports state; it does not prompt.
struct SmallWidgetView: View {
    /// The headline is the widest thing on a 170pt canvas and its text is
    /// data-driven, so "1 session" truncated to "1 ses..." on a real
    /// desktop widget. Shrink to fit rather than truncate: a slightly
    /// smaller number still reads at a glance, an elided one looks broken.
    private static let headlineMinimumScale: CGFloat = 0.6

    let snapshot: WidgetSnapshot
    let now: Date

    private var freshness: WidgetDataFreshness {
        WidgetDataFreshness.evaluate(generatedAt: snapshot.generatedAt, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
            // Deliberately not an exclamation mark. Prompting belongs to the
            // menu bar and notifications; the widget reports state, and the
            // state is that a session is paused waiting on the user, which
            // `pause.circle` says without raising an alarm. The old yellow
            // also never survived Tinted/Monochrome widget styles, which
            // substitute custom colors, so a semantic style renders more
            // predictably as well.
            glyph("pause.circle", color: .secondary)
            Text(snapshot.attentionCount == 1 ? "1 session" : "\(snapshot.attentionCount) sessions")
                .font(.system(size: 28, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Self.headlineMinimumScale)
            Text("needs you")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        } else if snapshot.activeCount > 0 {
            glyph("sparkle", color: .accentColor)
            Text(snapshot.activeCount == 1 ? "1 session" : "\(snapshot.activeCount) sessions")
                .font(.system(size: 28, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Self.headlineMinimumScale)
            Text("active")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        } else if let lowest = lowestWindow {
            glyph("gauge.with.dots.needle.33percent", color: WidgetColorPalette.color(for: lowest.provider))
            Text(WidgetSnapshotFormatting.percentLeftLabel(lowest.percentLeft))
                .font(.system(size: 28, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Self.headlineMinimumScale)
            Text(lowest.provider.displayName)
                .font(.system(size: 14, weight: .semibold))
            Text(lowest.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            glyph("checkmark.circle", color: .secondary)
            Text("All quiet")
                .font(.system(size: 28, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(Self.headlineMinimumScale)
        }
    }

    private func glyph(_ systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    /// Lowest individual window across every provider and window kind, not
    /// just each provider's current window: a provider can report a lower
    /// weekly percentage than its own (or another provider's) current one.
    private var lowestWindow: WidgetAllowanceWindow? {
        snapshot.allowances
            .flatMap(\.windows)
            .compactMap { window in
                window.percentLeft.map { (window, $0) }
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    private var footer: some View {
        Group {
            if freshness == .stale {
                Label("Stale", systemImage: "clock.arrow.circlepath")
            } else {
                Text(WidgetSnapshotFormatting.lastUpdatedLabel(snapshot.generatedAt, now: now))
            }
        }
        .font(.system(size: 11, weight: .medium))
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

#Preview("Allowance parity (identifies Codex Weekly, 19%)", as: .systemSmall) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.allowanceParitySnapshot)))
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
