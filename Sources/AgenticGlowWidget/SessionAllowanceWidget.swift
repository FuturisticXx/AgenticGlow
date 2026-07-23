import WidgetKit
import SwiftUI
import AgenticGlowCore

struct AgenticGlowTimelineProvider: TimelineProvider {
    let snapshotSource: any WidgetSnapshotLoading

    init(snapshotSource: any WidgetSnapshotLoading = AppGroupSnapshotSource()) {
        self.snapshotSource = snapshotSource
    }

    func placeholder(in context: Context) -> AgenticGlowWidgetEntry {
        AgenticGlowWidgetEntry(date: Date(), state: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (AgenticGlowWidgetEntry) -> Void) {
        if context.isPreview {
            // Entice the widget gallery with realistic sample data rather
            // than whatever the real (likely "not configured") state is.
            completion(AgenticGlowWidgetEntry(date: Date(), state: .result(.loaded(SampleData.busySnapshot))))
        } else {
            completion(currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgenticGlowWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // WidgetKit reloads whenever the app calls WidgetCenter.reloadTimelines
        // (a later pass) plus its own budget-managed schedule. This fallback
        // asks for one more check in 15 minutes in case the app never does,
        // e.g. it hasn't run since the widget was added.
        let nextRefresh = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> AgenticGlowWidgetEntry {
        AgenticGlowWidgetEntry(date: Date(), state: .result(snapshotSource.loadSnapshot()))
    }
}

struct SessionAllowanceWidget: Widget {
    let kind = "SessionAllowanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AgenticGlowTimelineProvider()) { entry in
            AgenticGlowWidgetView(entry: entry)
        }
        .configurationDisplayName("AgenticGlow")
        .description("Session status and usage allowance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
