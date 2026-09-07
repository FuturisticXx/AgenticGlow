import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Large's job: a richer dashboard. Up to 4 sessions, a per-provider
/// allowance block, and provider setup notices. No app title or
/// last-updated footer: on a real desktop widget canvas that content
/// routinely clipped off the bottom, and the title was redundant (the
/// widget gallery/desktop context already identifies it).
///
/// No attention banner either. Prompting the user about sessions that
/// need them is the menu bar's and the notifications' job; the widget
/// reports state. Each session row still carries its own phase ("Needs
/// you"), which is status rather than a prompt.
struct LargeWidgetView: View {
    let snapshot: WidgetSnapshot
    let now: Date
    var page: WidgetAllowancePage = .overview

    /// Matches the breathing room the system's own widgets leave above
    /// their first line.
    private static let topContentInset: CGFloat = 24

    var body: some View {
        // Claims the whole proposal and places content at the top
        // leading corner by construction. A fill-and-align frame does
        // not hold here: the container centers a page whose content does
        // not fill the canvas, which left the shorter Cursor page
        // starting lower than the default one.
        GeometryReader { _ in
            content
                // An overlay rather than a row: as the last child of the
                // stack the control was the first thing pushed past the
                // bottom edge whenever content ran long, and it rendered
                // sliced by the card's rounded corner. Overlaid it costs
                // no layout height, so it cannot displace an allowance
                // bar and cannot itself be pushed out.
                .overlay(alignment: .bottomTrailing) {
                    if showsDetailControl {
                        AllowanceDetailControl()
                    }
                }
        }
        // A uniform inset left the first session 12.5pt below the
        // rounded edge where the system's own widgets sit around 20pt.
        // The larger top inset is spent from the session area's budget
        // rather than added on top of a full canvas, which is what
        // LargeWidgetSessionBudget accounts for.
        .padding(.top, Self.topContentInset)
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: isCrowded ? 4 : 8) {
            if snapshot.sessions.isEmpty {
                if sessionLayout.rows > 0 {
                    Text("No active or recent sessions")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(snapshot.sessions.prefix(sessionLayout.rows)) { session in
                    SessionRow(session: session, now: now, style: .detailed)
                }
                if sessionLayout.hiddenCount > 0 {
                    Text("+ \(sessionLayout.hiddenCount) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            if page == .cursorDetail, let pooled = snapshot.poolAllowances.first {
                Divider()
                CursorDetailView(allowance: pooled, now: now)
            } else if !overviewAllowances.isEmpty {
                if !isCrowded {
                    Divider()
                }
                ForEach(overviewAllowances, id: \.provider) { allowance in
                    AllowanceStrip(
                        allowance: allowance,
                        showsResets: showsResetCaptions,
                        now: now
                    )
                }
            }
            ForEach(snapshot.providersWithoutData, id: \.self) { provider in
                Text("\(provider.displayName) not set up in AgenticGlow")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sessions and allowance windows share one fixed, non-scrolling
    /// canvas: more windows (each a heading + one bar per window) leaves
    /// less room for session rows before content clips off the bottom.
    ///
    /// The ceiling moved when Cursor gained two pools. Three providers
    /// with usage on now means six windows and three headings, which on
    /// their own fill the canvas, so the session list has to yield
    /// entirely rather than clip the last allowance bar off the bottom.
    /// Verified against the installed desktop widget, not just a preview.
    /// Beyond four windows the reset lines are what no longer fit. The
    /// percentages and the low warning are the glanceable part and stay;
    /// the reset detail is available in the popover.
    private var showsResetCaptions: Bool {
        !isCrowded
    }

    /// Three providers with usage on means six bars and three headings,
    /// which alone exceed the canvas. Past that point the layout sheds
    /// its chrome and detail in priority order (session rows, then the
    /// divider, then reset captions) so every provider's percentages
    /// still fit. Measured against the installed desktop widget.
    private var isCrowded: Bool {
        windowCount > 4
    }

    /// The default page carries the window providers only. A provider
    /// with pools has its own page, so switching Cursor usage on no
    /// longer changes this layout at all.
    private var overviewAllowances: [WidgetAllowanceSummary] {
        snapshot.overviewAllowances
    }

    private var windowCount: Int {
        overviewAllowances.flatMap(\.windows).count
    }

    /// The session area's whole vertical budget, including whether the
    /// "+ N more" line is being shown. Owned by Core so the rule is
    /// testable without rendering anything.
    private var sessionLayout: LargeWidgetSessionLayout {
        LargeWidgetSessionBudget.layout(
            sessionCount: snapshot.sessions.count,
            allowanceWindowCount: allowanceCost
        )
    }

    /// What the allowance section below the divider costs, expressed in
    /// the window count the budget is calibrated in. Measured per page
    /// rather than assumed, so the detail page gets a budget matching
    /// the two bars it actually draws instead of the four the overview
    /// draws.
    /// Only on the overview, and only when a provider with pools has
    /// data to show.
    private var showsDetailControl: Bool {
        page == .overview && !snapshot.poolAllowances.isEmpty
    }

    private var allowanceCost: Int {
        switch page {
        case .overview:
            return windowCount
        case .cursorDetail:
            // Two pool bars plus the page's own header row, which costs
            // about what one more window does.
            return (snapshot.poolAllowances.first?.windows.count ?? 0) + 1
        }
    }

}

#Preview("Busy", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.busySnapshot)))
}

#Preview("Allowance parity (3 windows)", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.allowanceParitySnapshot)))
}

#Preview("Cursor pools (Cursor Models + Other Models)", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.cursorPoolsSnapshot)))
}

#Preview("Low allowance", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.lowAllowanceSnapshot)))
}

#Preview("Failed session", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.failedSnapshot)))
}

#Preview("Provider not set up", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.idleSnapshot)))
}

#Preview("Stale", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.staleSnapshot)))
}

#Preview("No data yet", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.noSnapshotYet))
}
