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
    /// Set on the iPhone. The footer then reports the Mac's observation
    /// rather than the snapshot's build time, and the headline withdraws
    /// session counts once the Mac has gone offline.
    var provenance: WidgetSyncProvenance? = nil

    private var freshness: WidgetDataFreshness {
        WidgetDataFreshness.evaluate(generatedAt: footerDate, now: now)
    }

    /// The age the footer states belongs to the number on the canvas.
    /// When that number is an allowance, it is the provider's own read
    /// time: the snapshot can be newer than a reading the Mac could not
    /// refresh and carried forward.
    private var footerDate: Date {
        guard snapshot.attentionCount == 0, snapshot.activeCount == 0,
              let lowest = lowestWindow,
              let allowance = snapshot.allowances.first(where: { $0.provider == lowest.provider })
        else { return snapshot.generatedAt }
        return allowance.fetchedAt
    }

    private var syncFreshness: SyncFreshness? {
        provenance?.freshness(now: now)
    }

    /// Session counts stand for current activity, which an offline Mac
    /// cannot vouch for; allowances survive because their windows are
    /// dated. The headline drops to the allowance ladder in that case.
    private var showsSessionHeadlines: Bool {
        !(syncFreshness?.isOffline ?? false)
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
        if showsSessionHeadlines, snapshot.attentionCount > 0 {
            // Deliberately not an exclamation mark. Prompting belongs to the
            // menu bar and notifications; the widget reports state, and the
            // state is that a session is paused waiting on the user, which
            // `pause.circle` says without raising an alarm. The old yellow
            // also never survived Tinted/Monochrome widget styles, which
            // substitute custom colors, so a semantic style renders more
            // predictably as well.
            glyph("pause.circle", color: .secondary)
            Text(WidgetSmallCopy.title(for: snapshot))
                .font(.system(size: 28, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Self.headlineMinimumScale)
            Text(WidgetSmallCopy.subtitle(for: snapshot) ?? "needs you")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        } else if showsSessionHeadlines, snapshot.activeCount > 0 {
            glyph("sparkle", color: .accentColor)
            Text(WidgetSmallCopy.title(for: snapshot))
                .font(.system(size: 28, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Self.headlineMinimumScale)
            Text(WidgetSmallCopy.subtitle(for: snapshot) ?? "active")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        } else if let lowest = lowestWindow {
            glyph("gauge.with.dots.needle.33percent", color: WidgetColorPalette.color(for: lowest.provider))
            Text(WidgetSnapshotFormatting.percentLeftLabel(lowest.percentLeft, isDerived: lowest.isDerived))
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
    /// Cursor's pools are not eligible here. Small shows one number, and
    /// a pool percentage without room for its pool name would be the one
    /// thing this family must never show: a Cursor figure that does not
    /// say which allowance it belongs to.
    private var lowestWindow: WidgetAllowanceWindow? {
        snapshot.overviewAllowances
            .flatMap { $0.windows(asOf: provenance == nil ? nil : now) }
            .compactMap { window in
                window.percentLeft.map { (window, $0) }
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    @ViewBuilder
    private var footer: some View {
        Group {
            if let provenance {
                SyncStatusFooter(provenance: provenance, now: now, compact: true)
            } else if freshness == .stale {
                Label("Stale", systemImage: "clock.arrow.circlepath")
            } else {
                Text(WidgetSnapshotFormatting.lastUpdatedLabel(footerDate, now: now))
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

#Preview("Cursor pools (identifies Other Models)", as: .systemSmall) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(
        date: SampleData.now,
        state: .result(.loaded(SampleData.cursorPoolsIdleSnapshot))
    )
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
