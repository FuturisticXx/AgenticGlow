import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Large's job: a richer dashboard. Up to 4 sessions, attention elevated
/// above the rest, a per-provider allowance block, and provider setup
/// notices. No app title or last-updated footer: on a real desktop widget
/// canvas that content routinely clipped off the bottom, and the title was
/// redundant (the widget gallery/desktop context already identifies it).
struct LargeWidgetView: View {
    /// Upper bound when there are 0-2 allowance windows to show alongside
    /// sessions. `displayedSessionLimit` scales this down as the window
    /// count grows, since sessions and per-provider allowance blocks share
    /// one fixed, non-scrolling canvas.
    private static let maximumDisplayedSessions = 4

    let snapshot: WidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if snapshot.attentionCount > 0 {
                AttentionBanner(count: snapshot.attentionCount)
            }
            if snapshot.sessions.isEmpty {
                Text("No active or recent sessions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.sessions.prefix(displayedSessionLimit)) { session in
                    SessionRow(session: session, now: now, style: .detailed)
                }
                if snapshot.sessions.count > displayedSessionLimit {
                    Text("+ \(snapshot.sessions.count - displayedSessionLimit) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            if !snapshot.allowances.isEmpty {
                Divider()
                ForEach(snapshot.allowances, id: \.provider) { allowance in
                    AllowanceStrip(allowance: allowance, now: now)
                }
            }
            ForEach(notSetUpProviders, id: \.self) { provider in
                Text("\(provider.displayName) not set up in AgenticGlow")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    /// Sessions and allowance windows share one fixed, non-scrolling
    /// canvas: more windows (each a heading + one bar per window) leaves
    /// less room for session rows before content clips off the bottom.
    private var displayedSessionLimit: Int {
        let windowCount = snapshot.allowances.flatMap(\.windows).count
        switch windowCount {
        case 0...2: return Self.maximumDisplayedSessions
        case 3: return 3
        default: return 2
        }
    }

    private var notSetUpProviders: [AgentProvider] {
        snapshot.providers.filter { !$0.installed }.map(\.provider)
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
