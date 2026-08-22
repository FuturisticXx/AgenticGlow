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

    func testNeverMentionsCursor() {
        let line = AllowanceContinuation.line(allowances: [
            .claude: allowance(provider: .claude, currentLabel: "5h", currentLeft: 43, weeklyLeft: 1),
            .cursor: allowance(provider: .cursor, currentLabel: "unknown", currentLeft: 99, weeklyLeft: 99)
        ])
        XCTAssertEqual(line, "Claude weekly 1% left")
        XCTAssertFalse(line?.contains("Cursor") == true)
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
