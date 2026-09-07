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
