import WidgetKit
import SwiftUI
import AgenticGlowCore

struct AgenticGlowTimelineProvider: TimelineProvider {
    let snapshotSource: any WidgetSnapshotLoading
    let detailStateStore: any WidgetDetailStateStoring

    init(
        snapshotSource: any WidgetSnapshotLoading = AppGroupSnapshotSource(),
        detailStateStore: any WidgetDetailStateStoring = AppGroupDetailStateStore()
    ) {
        self.snapshotSource = snapshotSource
        self.detailStateStore = detailStateStore
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
        let now = Date()
        let result = snapshotSource.loadSnapshot()
        let entry = AgenticGlowWidgetEntry(date: now, state: .result(result), page: page(for: result, now: now))
        var entries = [entry]
        // The second entry is the whole auto-return mechanism: WidgetKit
        // renders it when its date arrives, so the Cursor page expires
        // without a timer, a wake-up, or an extra reload.
        if let returnsAt = overviewReturnsAt(for: result, now: now) {
            entries.append(
                AgenticGlowWidgetEntry(date: returnsAt, state: .result(result), page: .overview)
            )
        }
        // WidgetKit reloads whenever the app calls WidgetCenter.reloadTimelines
        // (a later pass) plus its own budget-managed schedule. This fallback
        // asks for one more check in 15 minutes in case the app never does,
        // e.g. it hasn't run since the widget was added.
        let nextRefresh = now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    private func currentEntry() -> AgenticGlowWidgetEntry {
        let now = Date()
        let result = snapshotSource.loadSnapshot()
        return AgenticGlowWidgetEntry(
            date: now,
            state: .result(result),
            page: page(for: result, now: now)
        )
    }

    private func page(for result: WidgetSnapshotLoadResult, now: Date) -> WidgetAllowancePage {
        guard case let .loaded(snapshot) = result else { return .overview }
        return WidgetDetailPresentation.page(
            state: detailStateStore.load(),
            snapshot: snapshot,
            now: now
        )
    }

    private func overviewReturnsAt(for result: WidgetSnapshotLoadResult, now: Date) -> Date? {
        guard case let .loaded(snapshot) = result else { return nil }
        return WidgetDetailPresentation.overviewReturnsAt(
            state: detailStateStore.load(),
            snapshot: snapshot,
            now: now
        )
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
