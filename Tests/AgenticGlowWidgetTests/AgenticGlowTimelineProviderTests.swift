import Foundation
import WidgetKit
import XCTest
import AgenticGlowCore

/// Exercises the real timeline provider (compiled into this bundle from the
/// extension's own sources) with a controlled snapshot source:
/// what the desktop widget renders is exactly what these entries carry.
final class AgenticGlowTimelineProviderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testLoadedSnapshotProducesAPopulatedOverviewEntry() {
        let snapshot = Self.snapshot(generatedAt: now)
        let provider = Self.provider(.loaded(snapshot))

        let timeline = provider.timeline(now: now)

        XCTAssertEqual(timeline.entries.count, 1)
        XCTAssertEqual(timeline.entries.first?.state, .result(.loaded(snapshot)))
        XCTAssertEqual(timeline.entries.first?.page, .overview)
        XCTAssertEqual(timeline.entries.first?.date, now)
        XCTAssertEqual(provider.currentEntry(now: now).state, .result(.loaded(snapshot)))
    }

    func testMissingSnapshotProducesTheWaitingState() {
        let provider = Self.provider(.noSnapshotYet)
        XCTAssertEqual(provider.timeline(now: now).entries.map(\.state), [.result(.noSnapshotYet)])
        XCTAssertEqual(provider.currentEntry(now: now).state, .result(.noSnapshotYet))
    }

    func testUnreadableSnapshotIsNotReportedAsWaiting() {
        let provider = Self.provider(.unreadable)
        let states = provider.timeline(now: now).entries.map(\.state)
        XCTAssertEqual(states, [.result(.unreadable)])
        XCTAssertNotEqual(states, [.result(.noSnapshotYet)])
    }

    func testCorruptedSnapshotProducesTheUnavailableState() {
        let provider = Self.provider(.corrupted)
        XCTAssertEqual(provider.timeline(now: now).entries.map(\.state), [.result(.corrupted)])
    }

    func testMissingContainerProducesTheNotConfiguredState() {
        let provider = Self.provider(.notConfigured)
        XCTAssertEqual(provider.timeline(now: now).entries.map(\.state), [.result(.notConfigured)])
    }

    func testStaleSnapshotStillRendersAsLoaded() {
        // Freshness is drawn as a caption over real data. The provider
        // never downgrades an old snapshot to an empty state.
        let old = now.addingTimeInterval(-(WidgetDataFreshness.staleThreshold + 60))
        let snapshot = Self.snapshot(generatedAt: old)
        let provider = Self.provider(.loaded(snapshot))
        XCTAssertEqual(provider.timeline(now: now).entries.first?.state, .result(.loaded(snapshot)))
    }

    func testNoTimelineEntryEverCarriesThePlaceholder() {
        // `.placeholder` is WidgetKit's redacted skeleton and exists only
        // for `placeholder(in:)`. If a real timeline could carry it, the
        // desktop would show gray bars forever while every check passed.
        let snapshot = Self.snapshot(generatedAt: now)
        let results: [WidgetSnapshotLoadResult] = [
            .loaded(snapshot), .noSnapshotYet, .unreadable, .corrupted, .notConfigured,
        ]
        for result in results {
            let provider = Self.provider(result)
            for entry in provider.timeline(now: now).entries {
                XCTAssertNotEqual(entry.state, .placeholder, "\(result) produced a placeholder entry")
            }
            XCTAssertNotEqual(provider.currentEntry(now: now).state, .placeholder)
        }
    }

    func testPlaceholderStateIsDistinctFromEveryRealResult() {
        XCTAssertNotEqual(WidgetPresentationState.placeholder, .result(.noSnapshotYet))
        XCTAssertNotEqual(WidgetPresentationState.placeholder, .result(.loaded(Self.snapshot(generatedAt: now))))
    }

    func testTimelineAsksForAFallbackRefreshInFifteenMinutes() {
        let provider = Self.provider(.noSnapshotYet)
        let policy = provider.timeline(now: now).policy
        XCTAssertEqual(policy, .after(now.addingTimeInterval(15 * 60)))
    }

    func testCursorDetailRequestSchedulesTheReturnToOverview() {
        let snapshot = Self.snapshot(generatedAt: now, withCursorPools: true)
        let state = WidgetDetailState.showingCursorDetail(from: now)
        let provider = AgenticGlowTimelineProvider(
            snapshotSource: StubSnapshotSource(result: .loaded(snapshot)),
            detailStateStore: StubDetailStateStore(state: state)
        )

        let entries = provider.timeline(now: now).entries

        XCTAssertEqual(entries.map(\.page), [.cursorDetail, .overview])
        XCTAssertEqual(entries.last?.date, state.cursorDetailUntil)
        XCTAssertEqual(entries.map(\.state), Array(repeating: .result(.loaded(snapshot)), count: 2))
    }

    func testWidgetKindAndDefaultsAreTheProductionOnes() {
        // The app reloads with `reloadAllTimelines`, which is kind-agnostic,
        // so a renamed kind cannot orphan a placed widget. The kind itself
        // is still what chronod stores against the timeline archive, and
        // the production provider must read the real App Group source.
        XCTAssertEqual(SessionAllowanceWidget().kind, "SessionAllowanceWidget")
        let provider = AgenticGlowTimelineProvider()
        XCTAssertTrue(provider.snapshotSource is AppGroupSnapshotSource)
        XCTAssertTrue(provider.detailStateStore is AppGroupDetailStateStore)
    }

    // MARK: - Fixtures

    private static func provider(_ result: WidgetSnapshotLoadResult) -> AgenticGlowTimelineProvider {
        AgenticGlowTimelineProvider(
            snapshotSource: StubSnapshotSource(result: result),
            detailStateStore: StubDetailStateStore(state: .empty)
        )
    }

    private static func snapshot(generatedAt: Date, withCursorPools: Bool = false) -> WidgetSnapshot {
        var allowances = [
            WidgetAllowanceSummary(
                provider: .codex,
                currentWindowLabel: "5h",
                currentPercentLeft: 100,
                currentResetAt: generatedAt.addingTimeInterval(3600),
                weeklyPercentLeft: 40,
                weeklyResetAt: generatedAt.addingTimeInterval(86_400),
                fetchedAt: generatedAt
            ),
        ]
        if withCursorPools {
            allowances.append(
                WidgetAllowanceSummary(
                    provider: .cursor,
                    currentWindowLabel: "Monthly",
                    currentPercentLeft: nil,
                    currentResetAt: nil,
                    weeklyPercentLeft: nil,
                    weeklyResetAt: nil,
                    pools: [
                        WidgetAllowancePool(id: "models", label: "Cursor Models", percentLeft: 80, resetAt: nil),
                        WidgetAllowancePool(id: "other", label: "Other Models", percentLeft: 60, resetAt: nil),
                    ],
                    fetchedAt: generatedAt
                )
            )
        }
        return WidgetSnapshot(
            generatedAt: generatedAt,
            sessions: [
                WidgetSessionSummary(
                    provider: .claude,
                    sessionID: "s1",
                    projectName: "Project",
                    phase: .usingTool,
                    toolCategory: nil,
                    elapsedSeconds: 60,
                    updatedAt: generatedAt,
                    needsAttention: false
                ),
            ],
            allowances: allowances,
            providers: [],
            attentionCount: 0,
            activeCount: 1,
            revision: 3
        )
    }
}

private struct StubSnapshotSource: WidgetSnapshotLoading {
    let result: WidgetSnapshotLoadResult
    func loadSnapshot() -> WidgetSnapshotLoadResult { result }
}

private struct StubDetailStateStore: WidgetDetailStateStoring {
    let state: WidgetDetailState
    func load() -> WidgetDetailState { state }
    func save(_ state: WidgetDetailState) {}
}
