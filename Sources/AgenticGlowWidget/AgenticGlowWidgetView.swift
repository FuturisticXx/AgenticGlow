import SwiftUI
import WidgetKit
import AgenticGlowCore

struct AgenticGlowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AgenticGlowWidgetEntry

    var body: some View {
        content
            .fontDesign(.default)
            .containerBackground(.background, for: .widget)
            .widgetURL(WidgetDeepLink.openApp.url)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .placeholder:
            LoadedContentView(
                snapshot: SampleData.busySnapshot,
                family: family,
                now: SampleData.now,
                page: .overview
            )
            .redacted(reason: .placeholder)
        case .result(.notConfigured):
            EmptyStateView(
                systemImage: "gearshape",
                title: "Set Up AgenticGlow",
                message: "Open AgenticGlow and finish setup to see live status here."
            )
        case .result(.noSnapshotYet):
            EmptyStateView(
                systemImage: "hourglass",
                title: "Waiting for AgenticGlow",
                message: "Status will appear here once AgenticGlow has run at least once."
            )
        case .result(.corrupted):
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Unavailable",
                message: "AgenticGlow's status could not be read. Open the app to refresh."
            )
        case .result(.unreadable):
            // The file is there; this widget process was refused access to
            // it. Reopening the app cannot help, so the copy says what can.
            EmptyStateView(
                systemImage: "lock.trianglebadge.exclamationmark",
                title: "Unavailable",
                message: "This widget isn't allowed to read AgenticGlow's status. Reinstall AgenticGlow to restore it."
            )
        case let .result(.loaded(snapshot)):
            LoadedContentView(snapshot: snapshot, family: family, now: entry.date, page: entry.page)
        }
    }
}

private struct LoadedContentView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    let now: Date
    let page: WidgetAllowancePage

    var body: some View {
        switch family {
        case .systemSmall:
            // Small stays on one number and stays non-interactive: its
            // whole canvas is a single headline, and a control there
            // would compete with the tap that opens the app.
            SmallWidgetView(snapshot: snapshot, now: now)
        case .systemMedium:
            MediumWidgetView(snapshot: snapshot, now: now, page: page)
        default:
            LargeWidgetView(snapshot: snapshot, now: now, page: page)
        }
    }
}
