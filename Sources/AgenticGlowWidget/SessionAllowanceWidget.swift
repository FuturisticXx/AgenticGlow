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
        completion(timeline(now: Date()))
    }

    /// The whole timeline for one refresh, separated from WidgetKit's
    /// callback so the real load -> entry mapping can be exercised with a
    /// controlled source and clock. Every entry here carries a `.result`;
    /// `.placeholder` is produced only by `placeholder(in:)`.
    func timeline(now: Date) -> Timeline<AgenticGlowWidgetEntry> {
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
        // One entry per allowance turning stale, so its "Updated" label is
        // drawn on time rather than whenever WidgetKit next grants a reload.
        // Same snapshot, so nothing else on the canvas moves.
        for date in WidgetDataFreshness.allowanceStaleTransitions(in: result, after: now) {
            entries.append(
                AgenticGlowWidgetEntry(date: date, state: .result(result), page: page(for: result, now: date))
            )
        }
        entries.sort { $0.date < $1.date }
        // WidgetKit also reloads whenever the app calls
        // WidgetCenter.reloadTimelines, plus its own budget-managed schedule.
        // This asks for one more read when the first allowance turns stale,
        // so a newer observation the app wrote without a reload replaces the
        // label, and otherwise in 15 minutes in case the app never reloads,
        // e.g. it hasn't run since the widget was added.
        let nextRefresh = WidgetDataFreshness.nextTimelineRefresh(for: result, now: now)
        return Timeline(entries: entries, policy: .after(nextRefresh))
    }

    func currentEntry(now: Date = Date()) -> AgenticGlowWidgetEntry {
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

#if os(iOS)
/// The iPhone's provider. Same entries, same views, same Cursor page
/// mechanism as the desktop provider; the difference is where the
/// snapshot comes from and that every entry carries the Mac's provenance.
///
/// Renders from the App Group cache first and CloudKit opportunistically
/// (`CachedSyncedStateSource`), because iOS decides when a widget may run
/// and a render must never wait on the network. Freshness is judged from
/// the Mac's `observedAt`, and the timeline carries an entry at each
/// freshness transition, so the widget turns stale and then offline on
/// time even if nothing wakes it in between. A fetched record that is old
/// therefore renders as old.
struct SyncedTimelineProvider: TimelineProvider {
    let stateSource: any SyncedStateLoading
    let detailStateStore: any WidgetDetailStateStoring

    init(
        stateSource: any SyncedStateLoading = CachedSyncedStateSource(
            cache: AppGroupSyncedStateStore(),
            fetcher: CloudKitSyncTransport()
        ),
        detailStateStore: any WidgetDetailStateStoring = AppGroupDetailStateStore()
    ) {
        self.stateSource = stateSource
        self.detailStateStore = detailStateStore
    }

    func placeholder(in context: Context) -> AgenticGlowWidgetEntry {
        AgenticGlowWidgetEntry(date: Date(), state: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (AgenticGlowWidgetEntry) -> Void) {
        if context.isPreview {
            completion(AgenticGlowWidgetEntry(
                date: Date(),
                state: .result(.loaded(SampleData.busySnapshot)),
                provenance: SampleData.provenance
            ))
            return
        }
        Task {
            let now = Date()
            let result = await stateSource.loadSyncedState()
            completion(entry(for: result, at: now, now: now, page: page(for: result, now: now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<AgenticGlowWidgetEntry>) -> Void) {
        Task {
            let now = Date()
            let result = await stateSource.loadSyncedState()
            var entries = [entry(for: result, at: now, now: now, page: page(for: result, now: now))]
            if let returnsAt = overviewReturnsAt(for: result, now: now) {
                entries.append(entry(for: result, at: returnsAt, now: now, page: .overview))
            }
            if case let .loaded(envelope) = result {
                for transition in SyncFreshness.transitions(after: envelope.observedAt, now: now) {
                    entries.append(entry(for: result, at: transition, now: now, page: .overview))
                }
            }
            entries.sort { $0.date < $1.date }
            // The app reloads the timeline when a push or a foreground
            // fetch brings new state; this is the fallback check for
            // when neither happens, within WidgetKit's own budget.
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }

    private func entry(
        for result: SyncedStateLoadResult,
        at date: Date,
        now: Date,
        page: WidgetAllowancePage
    ) -> AgenticGlowWidgetEntry {
        var entry = AgenticGlowWidgetEntry(date: date, state: .result(result.snapshotLoadResult), page: page)
        if case let .loaded(envelope) = result {
            entry.provenance = WidgetSyncProvenance(envelope)
        }
        return entry
    }

    private func page(for result: SyncedStateLoadResult, now: Date) -> WidgetAllowancePage {
        guard case let .loaded(envelope) = result else { return .overview }
        return WidgetDetailPresentation.page(state: detailStateStore.load(), snapshot: envelope.snapshot, now: now)
    }

    private func overviewReturnsAt(for result: SyncedStateLoadResult, now: Date) -> Date? {
        guard case let .loaded(envelope) = result else { return nil }
        return WidgetDetailPresentation.overviewReturnsAt(
            state: detailStateStore.load(),
            snapshot: envelope.snapshot,
            now: now
        )
    }
}
#endif

struct SessionAllowanceWidget: Widget {
    let kind = "SessionAllowanceWidget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        StaticConfiguration(kind: kind, provider: SyncedTimelineProvider()) { entry in
            AgenticGlowWidgetView(entry: entry)
        }
        .configurationDisplayName("AgenticGlow")
        .description("Your Mac's session status and usage allowance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // The views carry the desktop widget's own 16pt insets. iOS would
        // add its content margins on top, which doubled every inset and
        // pushed the medium layout off its canvas; without them the
        // insets match the system's own Home Screen widgets.
        .contentMarginsDisabled()
        #else
        StaticConfiguration(kind: kind, provider: AgenticGlowTimelineProvider()) { entry in
            AgenticGlowWidgetView(entry: entry)
        }
        .configurationDisplayName("AgenticGlow")
        .description("Session status and usage allowance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #endif
    }
}
