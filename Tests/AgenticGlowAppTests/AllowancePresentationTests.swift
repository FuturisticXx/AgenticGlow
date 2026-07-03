import Foundation
import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class AllowancePresentationTests: XCTestCase {
    func testCodexUsesLeftFirstCompactAndSpokenLabels() {
        let reset = Date(timeIntervalSince1970: 1_783_101_600)
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 26,
            currentResetAt: reset,
            weeklyPercentUsed: 18,
            weeklyResetAt: reset,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date(timeIntervalSince1970: 1_783_099_000))

        XCTAssertEqual(presentation.currentValue, "74% left")
        XCTAssertTrue(presentation.weeklyValue.hasPrefix("Week 82%"))
        XCTAssertTrue(presentation.accessibilityCurrent.contains("74 percent left"))
        XCTAssertTrue(presentation.accessibilityCurrent.contains("resets"))
    }

    func testClaudePreservesUsedContextWithoutReversingProgressDirection() {
        let allowance = ProviderAllowance(
            provider: .claude,
            currentWindowLabel: "Session",
            currentPercentUsed: 61,
            currentResetAt: nil,
            weeklyPercentUsed: 20,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertEqual(presentation.currentValue, "39% left · 61% used")
        XCTAssertEqual(presentation.currentProgress, 0.39, accuracy: 0.001)
        XCTAssertEqual(presentation.weeklyValue, "Week 80% · 20% used")
    }
}
