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

    func testCurrentWindowBelowThresholdIsLowAndSpokenAloud() {
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 91,
            currentResetAt: nil,
            weeklyPercentUsed: 50,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertTrue(presentation.currentIsLow)
        XCTAssertFalse(presentation.weeklyIsLow)
        XCTAssertTrue(presentation.accessibilityCurrent.contains("low"))
        XCTAssertFalse(presentation.accessibilityWeekly!.contains("low"))
    }

    func testExactThresholdIsNotLowInPresentation() {
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 90,
            currentResetAt: nil,
            weeklyPercentUsed: 90,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertFalse(presentation.currentIsLow)
        XCTAssertFalse(presentation.weeklyIsLow)
        XCTAssertFalse(presentation.accessibilityCurrent.contains("low"))
        XCTAssertFalse(presentation.accessibilityWeekly!.contains("low"))
    }

    func testWeeklyWindowBelowThresholdIsLowIndependentlyOfCurrent() {
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 50,
            currentResetAt: nil,
            weeklyPercentUsed: 95,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertFalse(presentation.currentIsLow)
        XCTAssertTrue(presentation.weeklyIsLow)
        XCTAssertFalse(presentation.accessibilityCurrent.contains("low"))
        XCTAssertTrue(presentation.accessibilityWeekly!.contains("low"))
    }

    func testBothWindowsBelowThresholdAreLowSimultaneously() {
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 92,
            currentResetAt: nil,
            weeklyPercentUsed: 95,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertTrue(presentation.currentIsLow)
        XCTAssertTrue(presentation.weeklyIsLow)
        XCTAssertTrue(presentation.accessibilityCurrent.contains("low"))
        XCTAssertTrue(presentation.accessibilityWeekly!.contains("low"))
    }

    func testCurrentResetShowsCountdownAndAbsoluteClockTime() {
        let reset = Date(timeIntervalSince1970: 1_783_101_600)
        let now = Date(timeIntervalSince1970: 1_783_099_000)
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 26,
            currentResetAt: reset,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: now)

        let expectedCountdown = "43m"
        let expectedClockTime = reset.formatted(date: .omitted, time: .shortened)
        XCTAssertTrue(presentation.currentDetail.contains(expectedCountdown))
        XCTAssertTrue(presentation.currentDetail.contains(expectedClockTime))
    }

    func testCurrentResetIncludesCalendarDateWhenNotToday() {
        // Codex sometimes reports only a weekly-scale window with no
        // separate secondary window (observed live); that window lands in
        // "current", so its reset can be days out and must show a date.
        let now = Date(timeIntervalSince1970: 1_783_099_000)
        let reset = now.addingTimeInterval(7 * 24 * 60 * 60)
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "Weekly",
            currentPercentUsed: 97,
            currentResetAt: reset,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: now)

        let expectedDate = reset.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        XCTAssertTrue(presentation.currentDetail.contains(expectedDate))
    }

    func testWeeklyResetShowsCalendarDateAlongsideWeekdayAndTime() {
        let reset = Date(timeIntervalSince1970: 1_783_101_600)
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: nil,
            currentResetAt: nil,
            weeklyPercentUsed: 18,
            weeklyResetAt: reset,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        let expected = reset.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        XCTAssertEqual(presentation.weeklyValue, "Week 82% · \(expected)")
    }

    func testMissingPercentagesAreNotLow() {
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: nil,
            currentResetAt: nil,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertFalse(presentation.currentIsLow)
        XCTAssertFalse(presentation.weeklyIsLow)
        XCTAssertFalse(presentation.accessibilityCurrent.contains("low"))
        XCTAssertNil(presentation.accessibilityWeekly)
    }
}
