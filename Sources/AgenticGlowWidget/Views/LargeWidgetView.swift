import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Large's job: a richer dashboard. Up to 4 sessions, attention elevated
/// above the rest, a per-provider allowance block, provider setup notices,
/// and a last-updated/staleness footer.
struct LargeWidgetView: View {
    /// Kept below WidgetSnapshotBuilder.maximumSessions: with a header,
    /// per-provider allowance blocks, and a footer all sharing the same
    /// fixed canvas, showing every capped session risks clipping content
    /// off the bottom instead of it just being unreachable via scrolling
    /// (widgets don't scroll).
    private static let maximumDisplayedSessions = 4

    let snapshot: WidgetSnapshot
    let now: Date

    private var freshness: WidgetDataFreshness {
        WidgetDataFreshness.evaluate(generatedAt: snapshot.generatedAt, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if snapshot.sessions.isEmpty {
                Text("No active or recent sessions")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.sessions.prefix(Self.maximumDisplayedSessions)) { session in
                    SessionRow(session: session, now: now, style: .detailed)
                }
                if snapshot.sessions.count > Self.maximumDisplayedSessions {
                    Text("+ \(snapshot.sessions.count - Self.maximumDisplayedSessions) more")
                        .font(.caption2.weight(.medium))
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
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            footer
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Text("AgenticGlow")
                .font(.headline.weight(.bold))
                .fontWidth(.condensed)
            Spacer()
            if snapshot.attentionCount > 0 {
                AttentionBanner(count: snapshot.attentionCount)
            }
        }
    }

    private var notSetUpProviders: [AgentProvider] {
        snapshot.providers.filter { !$0.installed }.map(\.provider)
    }

    private var footer: some View {
        Group {
            if freshness == .stale {
                Text("Stale, last updated \(WidgetSnapshotFormatting.lastUpdatedLabel(snapshot.generatedAt, now: now))")
            } else {
                Text("Updated \(WidgetSnapshotFormatting.lastUpdatedLabel(snapshot.generatedAt, now: now))")
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
    }
}

#Preview("Busy", as: .systemLarge) {
    SessionAllowanceWidget()
} timeline: {
    AgenticGlowWidgetEntry(date: SampleData.now, state: .result(.loaded(SampleData.busySnapshot)))
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
