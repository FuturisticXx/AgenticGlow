import Foundation
import XCTest
@testable import AgenticGlowCore

final class WidgetAllowanceWindowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testWeeklyOnlyCurrentWindowLabelProducesOneWindow() {
        let allowance = WidgetAllowanceSummary(
            provider: .codex,
            currentWindowLabel: "Weekly",
            currentPercentLeft: 19,
            currentResetAt: now.addingTimeInterval(86_400),
            weeklyPercentLeft: nil,
            weeklyResetAt: nil,
            fetchedAt: now
        )

        XCTAssertEqual(allowance.windows.count, 1)
        XCTAssertEqual(allowance.windows[0].kind, .current)
        XCTAssertEqual(allowance.windows[0].label, "Weekly")
    }

    func testCurrentPlusWeeklyProducesTwoWindowsInOrder() {
        let allowance = WidgetAllowanceSummary(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentLeft: 64,
            currentResetAt: now.addingTimeInterval(3600),
            weeklyPercentLeft: 53,
            weeklyResetAt: now.addingTimeInterval(4 * 86_400),
            fetchedAt: now
        )

        XCTAssertEqual(allowance.windows.count, 2)
        XCTAssertEqual(allowance.windows[0].label, "5h")
        XCTAssertEqual(allowance.windows[0].kind, .current)
        XCTAssertEqual(allowance.windows[1].label, "Weekly")
        XCTAssertEqual(allowance.windows[1].kind, .weekly)
    }

    func testCurrentCodexPlusClaudeProducesThreeWindows() {
        let codex = WidgetAllowanceSummary(
            provider: .codex,
            currentWindowLabel: "Weekly",
            currentPercentLeft: 19,
            currentResetAt: now.addingTimeInterval(86_400),
            weeklyPercentLeft: nil,
            weeklyResetAt: nil,
            fetchedAt: now
        )
        let claude = WidgetAllowanceSummary(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentLeft: 64,
            currentResetAt: now.addingTimeInterval(3600),
            weeklyPercentLeft: 53,
            weeklyResetAt: now.addingTimeInterval(4 * 86_400),
            fetchedAt: now
        )

        let allWindows = [codex, claude].flatMap(\.windows)
        XCTAssertEqual(allWindows.count, 3)
    }

    func testNormalizedProgressScalesPercentToUnitRange() {
        let window = WidgetAllowanceWindow(
            provider: .codex,
            kind: .current,
            label: "Weekly",
            percentLeft: 19,
            resetAt: nil
        )
        XCTAssertEqual(window.normalizedProgress ?? -1, 0.19, accuracy: 0.0001)
    }

    func testNormalizedProgressClampsNegativePercentToZero() {
        let window = WidgetAllowanceWindow(
            provider: .codex,
            kind: .current,
            label: "Weekly",
            percentLeft: -5,
            resetAt: nil
        )
        XCTAssertEqual(window.normalizedProgress, 0)
    }

    func testNormalizedProgressClampsAboveHundredPercentToOne() {
        let window = WidgetAllowanceWindow(
            provider: .codex,
            kind: .current,
            label: "Weekly",
            percentLeft: 140,
            resetAt: nil
        )
        XCTAssertEqual(window.normalizedProgress, 1)
    }

    func testNormalizedProgressStaysNilWhenPercentLeftIsNil() {
        let window = WidgetAllowanceWindow(
            provider: .codex,
            kind: .current,
            label: "Weekly",
            percentLeft: nil,
            resetAt: nil
        )
        XCTAssertNil(window.normalizedProgress)
    }
}
