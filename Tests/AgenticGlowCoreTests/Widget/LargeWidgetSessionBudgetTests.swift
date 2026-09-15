import Foundation
import XCTest
@testable import AgenticGlowCore

/// Regression cover for the large widget clipping its top session row.
///
/// The failure was a budget that counted session rows but not the "+ N
/// more" line they produce, so three sessions alongside four allowance
/// windows rendered two rows plus a summary line and pushed the first row
/// off the canvas. The invariant these tests hold is that variable
/// session content can never grow the session area beyond the space the
/// allowance section leaves it.
final class LargeWidgetSessionBudgetTests: XCTestCase {
    /// Codex and Claude both reporting a current and a weekly window,
    /// which is the shipping default and the case that clipped.
    private let codexAndClaude = 4

    func testOverflowingListCostsSpaceForItsSummaryLine() {
        let layout = LargeWidgetSessionBudget.layout(
            sessionCount: 3,
            allowanceWindowCount: codexAndClaude
        )

        XCTAssertEqual(layout.rows, 1, "The summary line has to be paid for")
        XCTAssertEqual(layout.hiddenCount, 2)
    }

    /// What raising the top content inset cost: the shipping default has
    /// room for one row plus a summary rather than two bare rows.
    func testTheTopInsetIsPaidForOutOfTheSessionArea() {
        let layout = LargeWidgetSessionBudget.layout(
            sessionCount: 2,
            allowanceWindowCount: codexAndClaude
        )

        XCTAssertEqual(layout.rows, 1)
        XCTAssertEqual(layout.hiddenCount, 1)
        XCTAssertLessThan(
            Double(layout.rows) * LargeWidgetSessionBudget.rowHeight
                + LargeWidgetSessionBudget.summaryHeight,
            LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: codexAndClaude)
                + 1
        )
    }

    /// The heart of the regression: whatever the session area actually
    /// draws must fit the space the insets and allowance section leave,
    /// however many sessions arrive.
    func testDrawnSessionContentNeverExceedsTheBudget() {
        for windows in 0...8 {
            let budget = LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: windows)
            for sessions in 0...12 {
                let layout = LargeWidgetSessionBudget.layout(
                    sessionCount: sessions,
                    allowanceWindowCount: windows
                )
                let drawn = Double(layout.rows) * LargeWidgetSessionBudget.rowHeight
                    + (layout.hiddenCount > 0 ? LargeWidgetSessionBudget.summaryHeight : 0)
                XCTAssertLessThanOrEqual(
                    drawn,
                    budget,
                    "\(sessions) sessions with \(windows) windows overflowed the budget"
                )
                XCTAssertLessThanOrEqual(layout.rows, sessions)
            }
        }
    }

    func testEverySessionIsAccountedForEitherAsARowOrInTheSummary() {
        for sessions in 0...12 {
            let layout = LargeWidgetSessionBudget.layout(
                sessionCount: sessions,
                allowanceWindowCount: codexAndClaude
            )
            XCTAssertEqual(
                layout.rows + layout.hiddenCount,
                sessions,
                "\(sessions) sessions went missing from the count"
            )
        }
    }

    func testZeroSessionsAsksForNoRowsAndNoSummary() {
        let layout = LargeWidgetSessionBudget.layout(
            sessionCount: 0,
            allowanceWindowCount: codexAndClaude
        )

        XCTAssertEqual(layout, LargeWidgetSessionLayout(rows: 0, hiddenCount: 0))
    }

    func testOneSessionKeepsItsRow() {
        XCTAssertEqual(
            LargeWidgetSessionBudget.layout(sessionCount: 1, allowanceWindowCount: codexAndClaude),
            LargeWidgetSessionLayout(rows: 1, hiddenCount: 0)
        )
    }

    func testManySessionsCollapseToOneRowAndASummary() {
        let layout = LargeWidgetSessionBudget.layout(
            sessionCount: 9,
            allowanceWindowCount: codexAndClaude
        )

        XCTAssertEqual(layout.rows, 1)
        XCTAssertEqual(layout.hiddenCount, 8)
    }

    /// The live case that exposed the original clipping.
    func testFiveLiveSessionsRenderOneRowAndASummary() {
        XCTAssertEqual(
            LargeWidgetSessionBudget.layout(sessionCount: 5, allowanceWindowCount: codexAndClaude),
            LargeWidgetSessionLayout(rows: 1, hiddenCount: 4)
        )
    }

    /// Fewer windows leave room for more rows, but the summary line is
    /// still paid for out of that room.
    func testASmallerAllowanceSectionAffordsMoreRows() {
        XCTAssertEqual(
            LargeWidgetSessionBudget.layout(sessionCount: 4, allowanceWindowCount: 2),
            LargeWidgetSessionLayout(rows: 4, hiddenCount: 0)
        )
        XCTAssertEqual(
            LargeWidgetSessionBudget.layout(sessionCount: 6, allowanceWindowCount: 2),
            LargeWidgetSessionLayout(rows: 4, hiddenCount: 2)
        )
    }

    /// At the tightest capacity the summary survives alone rather than
    /// the session area disappearing without a trace.
    func testTheSummaryAloneSurvivesAtTheTightestCapacity() {
        let layout = LargeWidgetSessionBudget.layout(
            sessionCount: 4,
            allowanceWindowCount: 5
        )

        XCTAssertEqual(layout.rows, 0)
        XCTAssertEqual(layout.hiddenCount, 4)
    }

    /// Six windows is three providers with usage on; the allowance
    /// section alone fills the canvas and the session area yields.
    func testTheSessionAreaYieldsEntirelyWhenAllowanceFillsTheCanvas() {
        XCTAssertEqual(
            LargeWidgetSessionBudget.layout(sessionCount: 5, allowanceWindowCount: 6),
            LargeWidgetSessionLayout(rows: 0, hiddenCount: 0)
        )
    }

    /// The four Codex and Claude windows are never traded away for a
    /// session row: the budget falls as the allowance section grows,
    /// never the reverse.
    func testTheSessionBudgetNeverGrowsAsTheAllowanceSectionGrows() {
        let budgets = (0...8).map(LargeWidgetSessionBudget.availablePoints(allowanceWindowCount:))

        XCTAssertEqual(budgets, budgets.sorted(by: >))
        XCTAssertLessThan(
            LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 4),
            2 * LargeWidgetSessionBudget.rowHeight,
            "Two bare rows must no longer fit beside four windows"
        )
    }
}

/// The large widget's single session row taking turns across natural
/// refreshes.
///
/// The invariants: selection only ever changes where a cycle starts, never
/// the snapshot's ordering; it cannot outrun the collection it is rotating
/// through; it costs the layout nothing, so "+ N more" and everything
/// below the row stay put; and it is a function of the snapshot alone, so
/// nothing time-based is needed to drive it.
final class LargeWidgetSessionRotationTests: XCTestCase {
    /// Codex and Claude both reporting a current and a weekly window,
    /// which is the shipping default.
    private let codexAndClaude = 4
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    private let oneRowPlusSummary = LargeWidgetSessionLayout(rows: 1, hiddenCount: 2)

    // MARK: - Selection

    func testNoSessionsSelectsNothing() {
        for revision in 0..<4 {
            XCTAssertTrue(
                LargeWidgetSessionRotation.visibleSessions(
                    [String](),
                    offset: revision,
                    layout: LargeWidgetSessionLayout(rows: 1, hiddenCount: 0)
                ).isEmpty,
                "Revision \(revision)"
            )
        }
    }

    func testASingleSessionNeverRotates() {
        let layout = LargeWidgetSessionBudget.layout(sessionCount: 1, allowanceWindowCount: codexAndClaude)

        XCTAssertEqual(layout, LargeWidgetSessionLayout(rows: 1, hiddenCount: 0))
        XCTAssertFalse(
            LargeWidgetSessionRotation.rotates(layout: layout),
            "One session has nothing to take turns with, and no + N more line"
        )
        for revision in 0..<6 {
            XCTAssertEqual(
                LargeWidgetSessionRotation.visibleSessions(["A"], offset: revision, layout: layout),
                ["A"],
                "Revision \(revision)"
            )
        }
    }

    func testTwoSessionsAlternate() {
        let layout = LargeWidgetSessionBudget.layout(sessionCount: 2, allowanceWindowCount: codexAndClaude)

        XCTAssertEqual(layout, LargeWidgetSessionLayout(rows: 1, hiddenCount: 1))
        XCTAssertTrue(LargeWidgetSessionRotation.rotates(layout: layout))
        XCTAssertEqual(visible(["A", "B"], revisions: 0..<4, layout: layout), [["A"], ["B"], ["A"], ["B"]])
    }

    func testThreeSessionsCycleInSnapshotOrderAndWrap() {
        XCTAssertEqual(
            visible(["A", "B", "C"], revisions: 0..<7, layout: oneRowPlusSummary),
            [["A"], ["B"], ["C"], ["A"], ["B"], ["C"], ["A"]]
        )
    }

    func testManySessionsCycleThroughEveryOneBeforeRepeating() {
        let sessions = ["A", "B", "C", "D", "E", "F", "G", "H"]
        let layout = LargeWidgetSessionLayout(rows: 1, hiddenCount: sessions.count - 1)

        XCTAssertEqual(
            visible(sessions, revisions: 0..<sessions.count, layout: layout).flatMap { $0 },
            sessions,
            "A full cycle shows each session once, in snapshot order"
        )
        XCTAssertEqual(
            LargeWidgetSessionRotation.visibleSessions(sessions, offset: sessions.count, layout: layout),
            ["A"],
            "The refresh after the last wraps to the first"
        )
    }

    /// Rotation moves where a cycle starts, never the sequence itself.
    func testARotatedWindowKeepsSnapshotOrderWhenSeveralRowsFit() {
        let layout = LargeWidgetSessionLayout(rows: 2, hiddenCount: 1)

        XCTAssertEqual(
            visible(["A", "B", "C"], revisions: 0..<4, layout: layout),
            [["A", "B"], ["B", "C"], ["C", "A"], ["A", "B"]]
        )
    }

    func testAFullyVisibleListNeverRotates() {
        let layout = LargeWidgetSessionLayout(rows: 3, hiddenCount: 0)

        XCTAssertFalse(LargeWidgetSessionRotation.rotates(layout: layout))
        for revision in 0..<5 {
            XCTAssertEqual(
                LargeWidgetSessionRotation.visibleSessions(["A", "B", "C"], offset: revision, layout: layout),
                ["A", "B", "C"],
                "A list showing everything must not reorder itself"
            )
        }
    }

    func testAYieldedSessionAreaShowsNothingAtEveryRevision() {
        let layout = LargeWidgetSessionBudget.layout(sessionCount: 3, allowanceWindowCount: 6)

        XCTAssertEqual(layout, LargeWidgetSessionLayout(rows: 0, hiddenCount: 0))
        XCTAssertFalse(LargeWidgetSessionRotation.rotates(layout: layout))
        for revision in 0..<5 {
            XCTAssertTrue(
                LargeWidgetSessionRotation.visibleSessions(["A", "B", "C"], offset: revision, layout: layout).isEmpty
            )
        }
    }

    // MARK: - A changed session set

    /// The snapshot is republished with fewer sessions than the revision
    /// it arrives with. The row has to land somewhere valid rather than
    /// reading off the end of the list.
    func testARevisionLargerThanTheSessionListStaysInRange() throws {
        for revision in [3, 4, 17, 900, Int.max] {
            let selected = LargeWidgetSessionRotation.visibleSessions(
                ["A", "B"],
                offset: revision,
                layout: LargeWidgetSessionLayout(rows: 1, hiddenCount: 1)
            )
            XCTAssertEqual(selected.count, 1, "Revision \(revision)")
            XCTAssertTrue(["A", "B"].contains(try XCTUnwrap(selected.first)), "Revision \(revision)")
        }
    }

    func testANegativeOffsetStaysInRange() {
        XCTAssertEqual(
            LargeWidgetSessionRotation.visibleSessions(["A", "B", "C"], offset: -1, layout: oneRowPlusSummary),
            ["C"]
        )
    }

    func testAskingForMoreRowsThanThereAreSessionsShowsWhatExists() {
        XCTAssertEqual(
            LargeWidgetSessionRotation.visibleSessions(
                ["A"],
                offset: 5,
                layout: LargeWidgetSessionLayout(rows: 3, hiddenCount: 0)
            ),
            ["A"]
        )
    }

    /// Sessions the snapshot never carried cannot appear: selection reads
    /// the published list, which the app's grouping, deduplication and
    /// visibility rules have already filtered, and has no other source.
    func testSelectionOnlyEverComesFromTheSessionsItWasGiven() {
        let eligible = ["visible-1", "visible-2", "visible-3"]

        for revision in 0..<30 {
            for selected in LargeWidgetSessionRotation.visibleSessions(
                eligible,
                offset: revision,
                layout: oneRowPlusSummary
            ) {
                XCTAssertTrue(eligible.contains(selected), "Revision \(revision) selected \(selected)")
            }
        }
    }

    // MARK: - No extra refresh mechanism

    /// The structural guarantee behind the whole design: the visible
    /// session is a function of the snapshot and nothing else. No date is
    /// an input, so no additional timeline entry, timer or reload could
    /// change the row. The provider therefore has nothing to emit for
    /// rotation, and the row advances only when new data arrives.
    func testTheVisibleSessionCannotChangeWithoutANewSnapshot() {
        let snapshot = snapshot(sessionCount: 3, revision: 7, includingCursor: false)
        let layout = LargeWidgetSessionBudget.layout(snapshot: snapshot, page: .overview)

        let selected = LargeWidgetSessionRotation.visibleSessions(
            snapshot.sessions,
            offset: snapshot.revision,
            layout: layout
        )

        for offset in [0.0, 5.0, 10.0, 600.0, 86_400.0] {
            let later = now.addingTimeInterval(offset)
            XCTAssertEqual(
                LargeWidgetSessionRotation.visibleSessions(
                    snapshot.sessions,
                    offset: snapshot.revision,
                    layout: LargeWidgetSessionBudget.layout(snapshot: snapshot, page: .overview)
                ).map(\.id),
                selected.map(\.id),
                "The row must be identical \(offset)s later on the same snapshot"
            )
            XCTAssertEqual(
                WidgetDetailPresentation.page(state: .empty, snapshot: snapshot, now: later),
                .overview
            )
        }
    }

    /// One published snapshot advances the row by exactly one place.
    func testEachPublishedSnapshotAdvancesTheRowByOne() {
        var seen: [String] = []
        for revision in 0..<6 {
            let snapshot = snapshot(sessionCount: 3, revision: revision, includingCursor: false)
            let layout = LargeWidgetSessionBudget.layout(snapshot: snapshot, page: .overview)
            let row = LargeWidgetSessionRotation.visibleSessions(
                snapshot.sessions,
                offset: snapshot.revision,
                layout: layout
            )
            XCTAssertEqual(row.count, 1)
            XCTAssertEqual(layout.hiddenCount, 2, "+ N more must not move")
            seen.append(row[0].sessionID)
        }
        XCTAssertEqual(
            seen,
            ["session-0", "session-1", "session-2", "session-0", "session-1", "session-2"]
        )
    }

    /// A revision only reaches the widget by being written, and a write
    /// only happens when something worth showing changed. The counter must
    /// therefore never be what makes a snapshot look different.
    func testTheRevisionAloneNeverMakesASnapshotWorthPublishing() {
        let first = snapshot(sessionCount: 3, revision: 1, includingCursor: false)
        let second = snapshot(sessionCount: 3, revision: 2, includingCursor: false)

        XCTAssertFalse(
            WidgetSnapshotBuilder.isMeaningfullyDifferent(second, from: first),
            "A bumped revision must not trigger a widget reload on its own"
        )
    }

    // MARK: - Budget and Cursor page

    func testTheSummaryCountIsTheSameAtEveryRevision() {
        let layout = LargeWidgetSessionBudget.layout(sessionCount: 3, allowanceWindowCount: codexAndClaude)

        for revision in 0..<9 {
            XCTAssertEqual(layout.hiddenCount, 2, "Revision \(revision)")
            XCTAssertEqual(
                LargeWidgetSessionRotation.visibleSessions(["A", "B", "C"], offset: revision, layout: layout).count,
                layout.rows,
                "Revision \(revision)"
            )
        }
    }

    func testTheCursorPageGetsItsOwnRowBudgetAndStillRotates() {
        let snapshot = snapshot(sessionCount: 3, revision: 0, includingCursor: true)

        let overview = LargeWidgetSessionBudget.layout(snapshot: snapshot, page: .overview)
        let detail = LargeWidgetSessionBudget.layout(snapshot: snapshot, page: .cursorDetail)

        XCTAssertEqual(LargeWidgetSessionBudget.allowanceWindowCount(snapshot: snapshot, page: .overview), 4)
        XCTAssertEqual(LargeWidgetSessionBudget.allowanceWindowCount(snapshot: snapshot, page: .cursorDetail), 3)
        XCTAssertEqual(overview, LargeWidgetSessionLayout(rows: 1, hiddenCount: 2))
        XCTAssertEqual(detail, LargeWidgetSessionLayout(rows: 2, hiddenCount: 1))
        XCTAssertTrue(LargeWidgetSessionRotation.rotates(layout: overview))
        XCTAssertTrue(LargeWidgetSessionRotation.rotates(layout: detail))
    }

    /// The row reads the snapshot's revision; the Cursor page reads one
    /// stored deadline. Neither is an input to the other, so a refresh
    /// that advances the row cannot dismiss the page early, and the page
    /// cannot freeze the row.
    func testAdvancingTheRowDoesNotDisturbTheCursorPage() {
        let state = WidgetDetailState.showingCursorDetail(from: now)
        let expiry = now.addingTimeInterval(WidgetDetailState.cursorDetailDuration)

        for revision in 0..<5 {
            let snapshot = snapshot(sessionCount: 3, revision: revision, includingCursor: true)
            // Part-way through the 12 second window, as a natural refresh
            // arriving while the page is up would be.
            let midway = now.addingTimeInterval(6)

            XCTAssertEqual(
                WidgetDetailPresentation.page(state: state, snapshot: snapshot, now: midway),
                .cursorDetail,
                "Revision \(revision) must not dismiss the page"
            )
            XCTAssertEqual(
                WidgetDetailPresentation.overviewReturnsAt(state: state, snapshot: snapshot, now: midway),
                expiry,
                "Revision \(revision) must not move the deadline"
            )
        }
    }

    // MARK: - Decoding

    /// A snapshot written before the counter existed has no revision key.
    /// It must still decode, and must show the first session.
    func testASnapshotWithoutARevisionDecodesAndShowsTheFirstSession() throws {
        let legacy = """
        {"schemaVersion":2,"generatedAt":752000000,"sessions":[],"allowances":[],
         "providers":[],"attentionCount":0,"activeCount":0}
        """
        let decoded = try JSONDecoder.agenticglow.decode(WidgetSnapshot.self, from: Data(legacy.utf8))

        XCTAssertEqual(decoded.revision, 0)
    }

    func testTheRevisionSurvivesARoundTrip() throws {
        let encoded = try JSONEncoder.agenticglow.encode(
            snapshot(sessionCount: 2, revision: 41, includingCursor: false)
        )

        XCTAssertEqual(try JSONDecoder.agenticglow.decode(WidgetSnapshot.self, from: encoded).revision, 41)
    }

    // MARK: - Helpers

    private func visible(
        _ sessions: [String],
        revisions: Range<Int>,
        layout: LargeWidgetSessionLayout
    ) -> [[String]] {
        revisions.map { LargeWidgetSessionRotation.visibleSessions(sessions, offset: $0, layout: layout) }
    }

    private func snapshot(sessionCount: Int, revision: Int, includingCursor: Bool) -> WidgetSnapshot {
        var allowances = [AgentProvider.codex, .claude].map { provider in
            WidgetAllowanceSummary(
                provider: provider,
                currentWindowLabel: "5h",
                currentPercentLeft: 45,
                currentResetAt: now.addingTimeInterval(3600),
                weeklyPercentLeft: 71,
                weeklyResetAt: now.addingTimeInterval(4 * 86_400),
                fetchedAt: now
            )
        }
        if includingCursor {
            allowances.append(
                WidgetAllowanceSummary(
                    provider: .cursor,
                    currentWindowLabel: "Billing cycle",
                    currentPercentLeft: nil,
                    currentResetAt: nil,
                    weeklyPercentLeft: nil,
                    weeklyResetAt: nil,
                    pools: [
                        WidgetAllowancePool(id: "cursorModels", label: "Cursor Models", percentLeft: 74, resetAt: nil),
                        WidgetAllowancePool(id: "otherModels", label: "Other Models", percentLeft: 6, resetAt: nil)
                    ],
                    fetchedAt: now
                )
            )
        }
        return WidgetSnapshot(
            generatedAt: now,
            sessions: (0..<sessionCount).map { index in
                WidgetSessionSummary(
                    provider: .claude,
                    sessionID: "session-\(index)",
                    projectName: "Project \(index)",
                    phase: .thinking,
                    toolCategory: nil,
                    elapsedSeconds: 30,
                    updatedAt: now,
                    needsAttention: false
                )
            },
            allowances: allowances,
            providers: [],
            attentionCount: 0,
            activeCount: sessionCount,
            revision: revision
        )
    }
}
