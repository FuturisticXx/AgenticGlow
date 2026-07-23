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
            LoadedContentView(snapshot: SampleData.busySnapshot, family: family, now: SampleData.now)
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
        case let .result(.loaded(snapshot)):
            LoadedContentView(snapshot: snapshot, family: family, now: entry.date)
        }
    }
}

private struct LoadedContentView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    let now: Date

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: snapshot, now: now)
        case .systemMedium:
            MediumWidgetView(snapshot: snapshot, now: now)
        default:
            LargeWidgetView(snapshot: snapshot, now: now)
        }
    }
}
