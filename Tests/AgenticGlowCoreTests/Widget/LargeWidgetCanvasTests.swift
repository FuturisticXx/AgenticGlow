import Foundation
import XCTest
@testable import AgenticGlowCore

/// The iPhone draws the large family on a taller canvas and spends a line
/// on its Mac footer. Its budget is its own; the desktop's figures, which
/// were measured against the installed widget, must not move.
final class LargeWidgetCanvasTests: XCTestCase {
    func testTheDesktopBudgetIsUnchanged() {
        XCTAssertEqual(LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 0, canvas: .macOS), 160)
        XCTAssertEqual(LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 2, canvas: .macOS), 160)
        XCTAssertEqual(LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 3, canvas: .macOS), 90)
        XCTAssertEqual(LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 4, canvas: .macOS), 52)
        XCTAssertEqual(LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 5, canvas: .macOS), 18)
        XCTAssertEqual(LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 6, canvas: .macOS), 0)
    }

    func testThisBuildUsesItsOwnPlatformsCanvas() {
        #if os(macOS)
        XCTAssertEqual(LargeWidgetSessionBudget.currentCanvas, .macOS)
        #else
        XCTAssertEqual(LargeWidgetSessionBudget.currentCanvas, .iOS)
        #endif
        XCTAssertEqual(
            LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 4),
            LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: 4, canvas: LargeWidgetSessionBudget.currentCanvas)
        )
    }

    func testTheiPhoneBudgetNeverGrowsAsTheAllowanceSectionGrows() {
        var previous = Double.infinity
        for windows in 0...7 {
            let budget = LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: windows, canvas: .iOS)
            XCTAssertLessThanOrEqual(budget, previous, "\(windows) windows")
            previous = budget
        }
    }

    /// The shipping default of four Codex and Claude windows keeps one
    /// row plus the summary on both canvases: the iPhone's extra height
    /// is spent on the footer. Measured in the simulator, where a second
    /// row ran the last reset caption into the footer.
    func testTheDefaultFourWindowsKeepOneRowAndTheSummaryOnBothCanvases() {
        let iOS = LargeWidgetSessionBudget.layout(sessionCount: 5, allowanceWindowCount: 4, canvas: .iOS)
        let macOS = LargeWidgetSessionBudget.layout(sessionCount: 5, allowanceWindowCount: 4, canvas: .macOS)
        XCTAssertEqual(iOS.rows, 1)
        XCTAssertEqual(iOS.hiddenCount, 4)
        XCTAssertEqual(macOS.rows, 1)
        XCTAssertEqual(macOS.hiddenCount, 4)
        // The Cursor page draws two bars and a header, and gets its rows back.
        XCTAssertEqual(LargeWidgetSessionBudget.layout(sessionCount: 5, allowanceWindowCount: 3, canvas: .iOS).rows, 2)
    }

    func testDrawnContentNeverExceedsTheiPhoneBudget() {
        for windows in 0...7 {
            for sessions in 0...WidgetSnapshotBuilder.maximumSessions {
                let layout = LargeWidgetSessionBudget.layout(sessionCount: sessions, allowanceWindowCount: windows, canvas: .iOS)
                let drawn = Double(layout.rows) * LargeWidgetSessionBudget.rowHeight
                    + (layout.hiddenCount > 0 ? LargeWidgetSessionBudget.summaryHeight : 0)
                XCTAssertLessThanOrEqual(
                    drawn,
                    LargeWidgetSessionBudget.availablePoints(allowanceWindowCount: windows, canvas: .iOS)
                )
                XCTAssertEqual(layout.rows + layout.hiddenCount, layout.rows > 0 ? sessions : layout.hiddenCount)
            }
        }
    }

    /// The Cursor page still hides on the iPhone by default and keeps its
    /// own, cheaper, budget.
    func testTheCursorPageIsBudgetedByItsOwnBarsOnEveryCanvas() {
        let now = Date(timeIntervalSince1970: 1_783_099_000)
        let cursor = WidgetAllowanceSummary(
            provider: .cursor, currentWindowLabel: "Billing cycle", currentPercentLeft: nil,
            currentResetAt: nil, weeklyPercentLeft: nil, weeklyResetAt: nil,
            pools: [
                WidgetAllowancePool(id: "cursorModels", label: "Cursor Models", percentLeft: 74, resetAt: now),
                WidgetAllowancePool(id: "otherModels", label: "Other Models", percentLeft: 6, resetAt: now)
            ],
            fetchedAt: now
        )
        let codex = WidgetAllowanceSummary(
            provider: .codex, currentWindowLabel: "5h", currentPercentLeft: 40, currentResetAt: now,
            weeklyPercentLeft: 30, weeklyResetAt: now, fetchedAt: now
        )
        let claude = WidgetAllowanceSummary(
            provider: .claude, currentWindowLabel: "5h", currentPercentLeft: 60, currentResetAt: now,
            weeklyPercentLeft: 50, weeklyResetAt: now, fetchedAt: now
        )
        let snapshot = WidgetSnapshot(
            generatedAt: now, sessions: [], allowances: [codex, claude, cursor],
            providers: [], attentionCount: 0, activeCount: 0
        )
        XCTAssertEqual(snapshot.overviewAllowances.map(\.provider), [.codex, .claude], "Cursor stays off the default page")
        XCTAssertEqual(LargeWidgetSessionBudget.allowanceWindowCount(snapshot: snapshot, page: .overview), 4)
        XCTAssertEqual(LargeWidgetSessionBudget.allowanceWindowCount(snapshot: snapshot, page: .cursorDetail), 3)
        for canvas in [LargeWidgetSessionBudget.Canvas.macOS, .iOS] {
            let overview = LargeWidgetSessionBudget.layout(snapshot: snapshot, page: .overview, canvas: canvas)
            let detail = LargeWidgetSessionBudget.layout(snapshot: snapshot, page: .cursorDetail, canvas: canvas)
            XCTAssertEqual(overview.rows, 0)
            XCTAssertEqual(detail.rows, 0)
        }
    }
}

final class MediumWidgetSessionBudgetTests: XCTestCase {
    func testTheDesktopKeepsItsFixedCaps() {
        for count in 0...8 {
            XCTAssertEqual(MediumWidgetSessionBudget.rows(sessionCount: count, page: .overview, hasFooter: false), 2)
            XCTAssertEqual(MediumWidgetSessionBudget.rows(sessionCount: count, page: .cursorDetail, hasFooter: false), 1)
        }
    }

    func testTheiPhoneTradesARowForTheSummaryLine() {
        XCTAssertEqual(MediumWidgetSessionBudget.rows(sessionCount: 0, page: .overview, hasFooter: true), 2)
        XCTAssertEqual(MediumWidgetSessionBudget.rows(sessionCount: 2, page: .overview, hasFooter: true), 2)
        XCTAssertEqual(MediumWidgetSessionBudget.rows(sessionCount: 3, page: .overview, hasFooter: true), 1)
        XCTAssertEqual(MediumWidgetSessionBudget.rows(sessionCount: 8, page: .overview, hasFooter: true), 1)
    }

    func testTheiPhoneCursorPageYieldsTheSessionArea() {
        XCTAssertEqual(MediumWidgetSessionBudget.rows(sessionCount: 5, page: .cursorDetail, hasFooter: true), 0)
    }
}
