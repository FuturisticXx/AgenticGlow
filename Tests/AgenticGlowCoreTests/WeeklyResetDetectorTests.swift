import Foundation
import XCTest
@testable import AgenticGlowCore

final class WeeklyResetDetectorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testRolloverIntoNewWeekDetectsReset() {
        XCTAssertTrue(WeeklyResetDetector.didReset(
            previous: allowance(weeklyResetAt: now.addingTimeInterval(-60)),
            current: allowance(weeklyResetAt: now.addingTimeInterval(6 * 86_400)),
            now: now
        ))
    }

    func testSameResetDateIsNotAReset() {
        let reset = now.addingTimeInterval(3 * 86_400)
        XCTAssertFalse(WeeklyResetDetector.didReset(
            previous: allowance(weeklyResetAt: reset),
            current: allowance(weeklyResetAt: reset),
            now: now
        ))
    }

    func testMissingPreviousIsNotAReset() {
        XCTAssertFalse(WeeklyResetDetector.didReset(
            previous: nil,
            current: allowance(weeklyResetAt: now.addingTimeInterval(6 * 86_400)),
            now: now
        ))
    }

    func testPreviousResetStillInFutureIsNotAReset() {
        XCTAssertFalse(WeeklyResetDetector.didReset(
            previous: allowance(weeklyResetAt: now.addingTimeInterval(3 * 86_400)),
            current: allowance(weeklyResetAt: now.addingTimeInterval(6 * 86_400)),
            now: now
        ))
    }

    func testMissingResetDatesAreNotAReset() {
        XCTAssertFalse(WeeklyResetDetector.didReset(
            previous: allowance(weeklyResetAt: now.addingTimeInterval(-60)),
            current: allowance(weeklyResetAt: nil),
            now: now
        ))
    }

    private func allowance(weeklyResetAt: Date?) -> ProviderAllowance {
        ProviderAllowance(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentUsed: 20,
            currentResetAt: nil,
            weeklyPercentUsed: 20,
            weeklyResetAt: weeklyResetAt,
            fetchedAt: now
        )
    }
}
