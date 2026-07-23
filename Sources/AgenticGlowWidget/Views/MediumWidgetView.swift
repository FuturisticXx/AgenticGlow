import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Medium's job: a compact operational summary. Up to 2 sessions, one
/// allowance strip for whichever provider is lowest, and an attention
/// banner pinned above everything when something needs the user.
struct MediumWidgetView: View {
    /// Medium's canvas is short; an attention banner, 2 session rows, and
    /// an allowance strip already fill it. More would risk clipping
    /// instead of just being unreachable (widgets don't scroll).
    private static let maximumDisplayedSessions = 2

    let snapshot: WidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if snapshot.attentionCount > 0 {
                AttentionBanner(count: snapshot.attentionCount)
            }
            if snapshot.sessions.isEmpty {
                Text("No active or recent sessions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.sessions.prefix(Self.maximumDisplayedSessions)) { session in
                    SessionRow(session: session, now: now, style: .compact)
                }
                if snapshot.sessions.count > Self.maximumDisplayedSessions {
                    Text("+ \(snapshot.sessions.count - Self.maximumDisplayedSessions) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let lowest = lowestWindow {
                AllowanceWindowRow(
                    window: lowest,
                    captionLabel: "\(lowest.provider.displayName) · \(lowest.label)",
                    now: now
                )
            }
        }
        .padding()
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
