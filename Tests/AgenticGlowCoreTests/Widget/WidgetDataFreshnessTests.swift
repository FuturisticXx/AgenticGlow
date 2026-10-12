import Foundation
import XCTest
@testable import AgenticGlowCore

final class WidgetDataFreshnessTests: XCTestCase {
    private let generatedAt = Date(timeIntervalSince1970: 1_783_099_000)

    func testWithinThresholdIsFresh() {
        let now = generatedAt.addingTimeInterval(WidgetDataFreshness.staleThreshold - 1)
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: generatedAt, now: now), .fresh)
    }

    func testAtThresholdIsFresh() {
        let now = generatedAt.addingTimeInterval(WidgetDataFreshness.staleThreshold)
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: generatedAt, now: now), .fresh)
    }

    func testBeyondThresholdIsStale() {
        let now = generatedAt.addingTimeInterval(WidgetDataFreshness.staleThreshold + 1)
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: generatedAt, now: now), .stale)
    }

    func testGeneratedInTheFutureIsFresh() {
        let now = generatedAt.addingTimeInterval(-60)
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: generatedAt, now: now), .fresh)
    }

    // MARK: - Timeline schedule across the stale threshold

    func testTimelineRefreshesWhenAFreshReadingTurnsStale() {
        let readAt = generatedAt.addingTimeInterval(-60)
        let result = WidgetSnapshotLoadResult.loaded(snapshot(readAt: [.codex: readAt]))
        let turnsStale = readAt.addingTimeInterval(WidgetDataFreshness.staleThreshold + 1)

        XCTAssertEqual(WidgetDataFreshness.allowanceStaleTransitions(in: result, after: generatedAt), [turnsStale])
        // Sooner than the 15-minute fallback, which on its own left the
        // reading unlabeled for up to 14 more minutes.
        XCTAssertEqual(WidgetDataFreshness.nextTimelineRefresh(for: result, now: generatedAt), turnsStale)
        XCTAssertLessThan(turnsStale, generatedAt.addingTimeInterval(WidgetDataFreshness.fallbackRefreshInterval))
    }

    func testEntryAtTheTransitionRendersTheStaleLabel() throws {
        let readAt = generatedAt.addingTimeInterval(-60)
        let snapshot = snapshot(readAt: [.codex: readAt])
        let transition = try XCTUnwrap(
            WidgetDataFreshness.allowanceStaleTransitions(in: .loaded(snapshot), after: generatedAt).first
        )
        let allowance = try XCTUnwrap(snapshot.allowances.first)

        XCTAssertNil(allowance.staleLabel(now: transition.addingTimeInterval(-1)))
        XCTAssertEqual(allowance.staleLabel(now: transition), "Updated 15m ago")
    }

    func testEachProviderGetsItsOwnTransitionInOrder() {
        let result = WidgetSnapshotLoadResult.loaded(snapshot(readAt: [
            .claude: generatedAt.addingTimeInterval(-60),
            .codex: generatedAt.addingTimeInterval(-600),
            .cursor: generatedAt.addingTimeInterval(-600)
        ]))
        let transitions = WidgetDataFreshness.allowanceStaleTransitions(in: result, after: generatedAt)

        XCTAssertEqual(transitions, [
            generatedAt.addingTimeInterval(-600 + WidgetDataFreshness.staleThreshold + 1),
            generatedAt.addingTimeInterval(-60 + WidgetDataFreshness.staleThreshold + 1)
        ])
    }

    func testAlreadyStaleReadingSchedulesNoTransitionAndKeepsTheFallback() {
        let result = WidgetSnapshotLoadResult.loaded(snapshot(readAt: [.codex: generatedAt.addingTimeInterval(-16 * 3600)]))

        XCTAssertTrue(WidgetDataFreshness.allowanceStaleTransitions(in: result, after: generatedAt).isEmpty)
        XCTAssertEqual(
            WidgetDataFreshness.nextTimelineRefresh(for: result, now: generatedAt),
            generatedAt.addingTimeInterval(WidgetDataFreshness.fallbackRefreshInterval)
        )
        XCTAssertEqual(
            WidgetDataFreshness.nextTimelineRefresh(for: .noSnapshotYet, now: generatedAt),
            generatedAt.addingTimeInterval(WidgetDataFreshness.fallbackRefreshInterval)
        )
    }

    private func snapshot(readAt: [AgentProvider: Date]) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: generatedAt,
            sessions: [],
            allowances: AgentProvider.allCases.compactMap { provider in
                readAt[provider].map {
                    WidgetAllowanceSummary(
                        provider: provider, currentWindowLabel: "5h",
                        currentPercentLeft: 60, currentResetAt: nil,
                        weeklyPercentLeft: 50, weeklyResetAt: nil,
                        fetchedAt: $0
                    )
                }
            },
            providers: [],
            attentionCount: 0,
            activeCount: 0
        )
    }
}
