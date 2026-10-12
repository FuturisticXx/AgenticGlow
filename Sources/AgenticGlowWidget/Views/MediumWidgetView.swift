import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Medium's job: a compact operational summary. Up to 2 sessions and one
/// allowance strip for whichever provider is lowest.
///
/// No attention banner: prompting the user about sessions that need them
/// is the menu bar's and the notifications' job; the widget reports
/// state. Each session row still carries its own phase ("Needs you"),
/// which is status rather than a prompt.
struct MediumWidgetView: View {
    /// The Cursor page needs two bars where the overview needs one, so
    /// the session list gives up a row for as long as it is showing. The
    /// iPhone's footer costs a line too (`MediumWidgetSessionBudget`).
    private var displayedSessionLimit: Int {
        MediumWidgetSessionBudget.rows(
            sessionCount: snapshot.sessions.count,
            page: page,
            hasFooter: provenance != nil
        )
    }

    let snapshot: WidgetSnapshot
    let now: Date
    var page: WidgetAllowancePage = .overview
    /// Set on the iPhone: adds the Mac footer and withdraws what an
    /// offline Mac cannot vouch for. Nil on the desktop, which is
    /// unchanged.
    var provenance: WidgetSyncProvenance? = nil

    private var syncFreshness: SyncFreshness? {
        provenance?.freshness(now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: provenance == nil ? 6 : 4) {
            if displayedSessionLimit == 0 {
                // The session area has yielded to the page's bars.
            } else if syncFreshness?.isOffline == true {
                Text(SyncStatusCopy.offlineSessionsLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if snapshot.sessions.isEmpty {
                Text("No active or recent sessions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.sessions.prefix(displayedSessionLimit)) { session in
                    SessionRow(
                        session: session,
                        now: now,
                        style: .compact,
                        showsElapsed: syncFreshness?.isFresh ?? true
                    )
                }
                if snapshot.sessions.count > displayedSessionLimit {
                    Text("+ \(snapshot.sessions.count - displayedSessionLimit) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if page == .cursorDetail, let pooled = snapshot.poolAllowances.first {
                CursorDetailView(allowance: pooled, now: now, showsHeader: false)
            } else if let lowest = lowestWindow {
                AllowanceWindowRow(
                    window: lowest,
                    captionLabel: "\(lowest.provider.displayName) · \(lowest.label)",
                    staleLabel: snapshot.allowances
                        .first { $0.provider == lowest.provider }?
                        .staleLabel(now: now),
                    now: now
                )
                if provenance == nil, !snapshot.poolAllowances.isEmpty {
                    AllowanceDetailControl()
                }
            }
            if let provenance {
                // The footer and the chevron share the last line: the
                // iPhone's medium canvas has no row to spare for each.
                HStack(alignment: .center, spacing: 0) {
                    SyncStatusFooter(provenance: provenance, now: now)
                    Spacer(minLength: 8)
                    if page == .overview, !snapshot.poolAllowances.isEmpty {
                        AllowanceDetailControl(compact: true)
                    }
                }
            }
        }
        .padding()
    }

    /// Lowest individual window across every provider and window kind, not
    /// just each provider's current window: a provider can report a lower
    /// weekly percentage than its own (or another provider's) current one.
    /// Cursor is excluded here for the same reason it is on large: its
    /// pools belong to their own page, not to the one line the medium
    /// canvas can spare.
    private var lowestWindow: WidgetAllowanceWindow? {
        snapshot.overviewAllowances
            .flatMap { $0.windows(asOf: provenance == nil ? nil : now) }
            .compactMap { window in
                window.percentLeft.map { (window, $0) }
            }
            .min { $0.1 < $1.1 }?
            .0
    }
}

#Preview("Busy", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.busySnapshot)))
}

#Preview("Allowance parity (picks Codex Weekly, 19%)", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.allowanceParitySnapshot)))
}

#Preview("Cursor pools (picks Other Models, 6%)", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.cursorPoolsSnapshot)))
}

#Preview("Attention only", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.attentionOnlySnapshot)))
}

#Preview("Failed session", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.failedSnapshot)))
}

#Preview("All quiet", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.idleSnapshot)))
}

#Preview("No data yet", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.noSnapshotYet))
}

#Preview("Not configured", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.notConfigured))
}

#Preview("Error", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.corrupted))
}

#Preview("Unreadable", as: .systemMedium) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.unreadable))
}
