import Foundation
import XCTest
@testable import AgenticGlowCore

final class AllowanceWarningTests: XCTestCase {
    func testCurrentWindowLowReturnsCurrentWindow() {
        let reset = Date(timeIntervalSince1970: 1_783_101_600)
        let windows = AllowanceWarning.lowWindows(in: allowance(
            currentUsed: 95,
            currentResetAt: reset,
            weeklyUsed: 50
        ))

        XCTAssertEqual(windows, [
            AllowanceWarning.Window(label: "5h", percentLeft: 5, resetAt: reset)
        ])
    }

    func testHealthyAllowanceReturnsNoWindows() {
        XCTAssertEqual(
            AllowanceWarning.lowWindows(in: allowance(currentUsed: 50, weeklyUsed: 50)),
            []
        )
    }

    func testExactThresholdIsNotLow() {
        XCTAssertEqual(
            AllowanceWarning.lowWindows(in: allowance(currentUsed: 90, weeklyUsed: 90)),
            []
        )
    }

    func testBothWindowsLowReturnsBoth() {
        let windows = AllowanceWarning.lowWindows(in: allowance(
            currentUsed: 96,
            weeklyUsed: 92
        ))

        XCTAssertEqual(windows.map(\.label), ["5h", "week"])
        XCTAssertEqual(windows.map(\.percentLeft), [4, 8])
    }

    func testMissingPercentagesReturnNoWindows() {
        XCTAssertEqual(
            AllowanceWarning.lowWindows(in: allowance(currentUsed: nil, weeklyUsed: nil)),
            []
        )
    }

    private func allowance(
        currentUsed: Double?,
        currentResetAt: Date? = nil,
        weeklyUsed: Double?,
        weeklyResetAt: Date? = nil
    ) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentUsed,
            currentResetAt: currentResetAt,
            weeklyPercentUsed: weeklyUsed,
            weeklyResetAt: weeklyResetAt,
            fetchedAt: Date(timeIntervalSince1970: 1_783_099_000)
        )
    }
}
