import XCTest
@testable import AgenticGlowCore

final class AllowanceContinuationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testHealthyWindowsShowNothing() {
        let line = AllowanceContinuation.line(allowances: [
            .claude: allowance(provider: .claude, currentLabel: "5h", currentLeft: 43, weeklyLeft: 54),
            .codex: allowance(provider: .codex, currentLabel: "Weekly", currentLeft: 54, weeklyLeft: 54)
        ])
        XCTAssertNil(line)
    }

    func testClaudeWeeklyLowIncludesCodexFact() {
        let line = AllowanceContinuation.line(allowances: [
            .claude: allowance(provider: .claude, currentLabel: "5h", currentLeft: 43, weeklyLeft: 1),
            .codex: allowance(provider: .codex, currentLabel: "Weekly", currentLeft: 54, weeklyLeft: 54)
        ])
        XCTAssertEqual(line, "Claude weekly 1% left. Codex 54% left")
    }

    func testOnlyClaudeLowOmitsMissingCodex() {
        let line = AllowanceContinuation.line(allowances: [
            .claude: allowance(provider: .claude, currentLabel: "5h", currentLeft: 43, weeklyLeft: 1)
        ])
        XCTAssertEqual(line, "Claude weekly 1% left")
    }

    /// With Cursor usage access off there is no Cursor allowance to
    /// report, so the line cannot name it. This replaces the older
    /// blanket "never mentions Cursor" rule, which existed only because
    /// Cursor had no usage source at all.
    func testCursorIsUnnamedWithoutUsageAccess() {
        let line = AllowanceContinuation.line(allowances: [
            .claude: allowance(provider: .claude, currentLabel: "5h", currentLeft: 43, weeklyLeft: 1)
        ])

        XCTAssertEqual(line, "Claude weekly 1% left")
        XCTAssertFalse(line?.contains("Cursor") == true)
    }

    /// With usage access on, a constrained Cursor pool is named
    /// specifically, so "Cursor" alone never stands for one of its two
    /// separate allowances.
    func testConstrainedCursorPoolIsNamedSpecifically() {
        let line = AllowanceContinuation.line(allowances: [
            .cursor: ProviderAllowance(
                provider: .cursor,
                currentWindowLabel: "Billing cycle",
                currentPercentUsed: nil,
                currentResetAt: nil,
                weeklyPercentUsed: nil,
                weeklyResetAt: nil,
                pools: [
                    AllowancePool(
                        id: "cursorModels",
                        label: "Cursor Models",
                        percentUsed: 26,
                        resetAt: now
                    ),
                    AllowancePool(
                        id: "otherModels",
                        label: "Other Models",
                        percentUsed: 96,
                        resetAt: now
                    )
                ],
                fetchedAt: now
            )
        ])

        XCTAssertEqual(line, "Cursor · Other Models 4% left")
    }

    func testZeroPercentIsConstrained() {
        let line = AllowanceContinuation.line(allowances: [
            .claude: allowance(provider: .claude, currentLabel: "5h", currentLeft: 0, weeklyLeft: 40)
        ])
        XCTAssertEqual(line, "Claude 5h 0% left")
    }

    func testTenPercentIsNotConstrained() {
        let line = AllowanceContinuation.line(allowances: [
            .claude: allowance(provider: .claude, currentLabel: "5h", currentLeft: 10, weeklyLeft: 40)
        ])
        XCTAssertNil(line)
    }

    private func allowance(
        provider: AgentProvider,
        currentLabel: String,
        currentLeft: Double,
        weeklyLeft: Double
    ) -> ProviderAllowance {
        ProviderAllowance(
            provider: provider,
            currentWindowLabel: currentLabel,
            currentPercentUsed: 100 - currentLeft,
            currentResetAt: now.addingTimeInterval(3600),
            weeklyPercentUsed: 100 - weeklyLeft,
            weeklyResetAt: now.addingTimeInterval(86_400),
            fetchedAt: now
        )
    }
}
