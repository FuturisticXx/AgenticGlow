import Foundation
import XCTest
@testable import AgenticGlowCore

/// The case these cover is the 2026-09-21 capture: an iPhone showing an
/// overnight snapshot's allowance as though it were current.
final class AllowanceWindowRolloverTests: XCTestCase {
    private let fiveHours: TimeInterval = 5 * 60 * 60

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - The capture this exists for

    /// Codex read 84% over "5h resets in Resetting (12:14 AM)" at 09:58,
    /// from a snapshot taken at 22:58 the night before. The window had
    /// rolled at 00:14 and again at 05:14 with the Mac asleep, so nothing
    /// spent it.
    func testCodexFiveHourWindowFromTheCaptureReadsAsFull() {
        let result = AllowanceWindowRollover.apply(
            percentLeft: 84,
            resetAt: date(9, 21, 0, 14),
            duration: fiveHours,
            now: date(9, 21, 9, 58)
        )
        XCTAssertEqual(result.percentLeft, 100)
        XCTAssertEqual(result.resetAt, date(9, 21, 10, 14))
        XCTAssertTrue(result.isDerived)
    }

    func testClaudeFiveHourWindowFromTheCaptureReadsAsFull() {
        let result = AllowanceWindowRollover.apply(
            percentLeft: 57,
            resetAt: date(9, 21, 2, 0),
            duration: fiveHours,
            now: date(9, 21, 9, 58)
        )
        XCTAssertEqual(result.percentLeft, 100)
        XCTAssertEqual(result.resetAt, date(9, 21, 12, 0))
        XCTAssertTrue(result.isDerived)
    }

    /// The same capture's weekly windows were still days out. A window
    /// that has not ended is not this type's business, and touching it
    /// would discard a real reading.
    func testWeeklyWindowStillAheadIsUntouched() {
        let reset = date(9, 26, 13, 23)
        let result = AllowanceWindowRollover.apply(
            percentLeft: 78,
            resetAt: reset,
            duration: AllowanceWindowRollover.weeklyDuration,
            now: date(9, 21, 9, 58)
        )
        XCTAssertEqual(result.percentLeft, 78)
        XCTAssertEqual(result.resetAt, reset)
        XCTAssertFalse(result.isDerived)
    }

    // MARK: - Boundaries

    func testNowExactlyOnABoundaryBelongsToTheWindowItOpened() {
        XCTAssertEqual(
            AllowanceWindowRollover.nextBoundary(after: date(9, 21, 0), duration: fiveHours, now: date(9, 21, 10)),
            date(9, 21, 15)
        )
    }

    func testOneSecondBeforeABoundaryStillNamesThatBoundary() {
        XCTAssertEqual(
            AllowanceWindowRollover.nextBoundary(
                after: date(9, 21, 0),
                duration: fiveHours,
                now: date(9, 21, 10).addingTimeInterval(-1)
            ),
            date(9, 21, 10)
        )
    }

    func testResetEqualToNowAdvancesOneWholePeriod() {
        let start = date(9, 21, 0)
        XCTAssertEqual(
            AllowanceWindowRollover.nextBoundary(after: start, duration: fiveHours, now: start),
            date(9, 21, 5)
        )
    }

    /// Thirty days is exactly 144 five-hour periods, so `now` lands on a
    /// boundary and the next one is a further five hours out. Advancing
    /// in whole periods rather than stepping is what keeps a gap this
    /// size the same cost as an hour.
    func testLongGapAdvancesInWholePeriods() {
        let start = date(9, 21, 0)
        XCTAssertEqual(
            AllowanceWindowRollover.nextBoundary(after: start, duration: fiveHours, now: date(10, 21, 0)),
            date(10, 21, 5)
        )
        XCTAssertEqual(
            AllowanceWindowRollover.nextBoundary(after: start, duration: fiveHours, now: date(10, 21, 2)),
            date(10, 21, 5)
        )
    }

    // MARK: - What it refuses to claim

    func testNoResetMeansNothingCanHaveElapsed() {
        let result = AllowanceWindowRollover.apply(
            percentLeft: 84,
            resetAt: nil,
            duration: fiveHours,
            now: date(9, 21, 9, 58)
        )
        XCTAssertEqual(result.percentLeft, 84)
        XCTAssertNil(result.resetAt)
        XCTAssertFalse(result.isDerived)
    }

    /// A provider that reported no figure does not acquire one just
    /// because its window turned over. The boundary is still corrected,
    /// so no caption counts down to a reset already behind it.
    func testAbsentPercentageIsNeverInvented() {
        let result = AllowanceWindowRollover.apply(
            percentLeft: nil,
            resetAt: date(9, 21, 0, 14),
            duration: fiveHours,
            now: date(9, 21, 9, 58)
        )
        XCTAssertNil(result.percentLeft)
        XCTAssertEqual(result.resetAt, date(9, 21, 10, 14))
        XCTAssertFalse(result.isDerived)
    }

    /// Cursor states a billing cycle with no period. The figure is still
    /// known to be spent, but the next boundary genuinely is not known,
    /// and a guess would be worse than silence.
    func testWindowWithoutAPeriodCorrectsThePercentageButNotTheBoundary() {
        let result = AllowanceWindowRollover.apply(
            percentLeft: 84,
            resetAt: date(9, 21, 0, 14),
            duration: nil,
            now: date(9, 21, 9, 58)
        )
        XCTAssertEqual(result.percentLeft, 100)
        XCTAssertNil(result.resetAt)
        XCTAssertTrue(result.isDerived)
    }

    func testNonPositiveOrNonFinitePeriodsAreRefused() {
        let start = date(9, 21, 0)
        let now = date(9, 21, 9, 58)
        XCTAssertNil(AllowanceWindowRollover.nextBoundary(after: start, duration: 0, now: now))
        XCTAssertNil(AllowanceWindowRollover.nextBoundary(after: start, duration: -fiveHours, now: now))
        XCTAssertNil(AllowanceWindowRollover.nextBoundary(after: start, duration: .nan, now: now))
        XCTAssertNil(AllowanceWindowRollover.nextBoundary(after: start, duration: .infinity, now: now))
    }

    /// A reset centuries in the past is a corrupt date, not an old one.
    func testAbsurdPeriodCountIsRefusedRatherThanComputed() {
        XCTAssertNil(
            AllowanceWindowRollover.nextBoundary(
                after: Date(timeIntervalSince1970: -500 * 365 * 24 * 60 * 60),
                duration: 1,
                now: date(9, 21, 9, 58)
            )
        )
    }

    // MARK: - The projection the widget actually calls

    /// The desktop passes nil and must be unaffected, because there a
    /// reset in the past really is one in progress.
    func testProjectionWithoutADateLeavesEveryWindowAsObserved() {
        let summary = WidgetAllowanceSummary(
            provider: .codex,
            currentWindowLabel: "5h",
            currentWindowDuration: fiveHours,
            currentPercentLeft: 84,
            currentResetAt: date(9, 21, 0, 14),
            weeklyPercentLeft: 78,
            weeklyResetAt: date(9, 26, 13, 23),
            fetchedAt: date(9, 20, 22, 58)
        )
        let windows = summary.windows
        XCTAssertEqual(windows.map(\.percentLeft), [84, 78])
        XCTAssertFalse(windows.contains { $0.isDerived })
    }

    /// The whole capture through the projection the views call: the 5h
    /// window is re-read, the weekly one is left alone.
    func testProjectionAsOfRollsOnlyTheElapsedWindow() {
        let summary = WidgetAllowanceSummary(
            provider: .codex,
            currentWindowLabel: "5h",
            currentWindowDuration: fiveHours,
            currentPercentLeft: 84,
            currentResetAt: date(9, 21, 0, 14),
            weeklyPercentLeft: 78,
            weeklyResetAt: date(9, 26, 13, 23),
            fetchedAt: date(9, 20, 22, 58)
        )
        let windows = summary.windows(asOf: date(9, 21, 9, 58))
        XCTAssertEqual(windows.map(\.percentLeft), [100, 78])
        XCTAssertEqual(windows.map(\.isDerived), [true, false])
        XCTAssertEqual(windows.first?.resetAt, date(9, 21, 10, 14))
    }

    /// A Mac running a build that predates durations sends no period, so
    /// the phone cannot roll the current window. It must degrade to the
    /// old behavior rather than guessing a period.
    func testSnapshotWithoutADurationDoesNotGuessOne() {
        let summary = WidgetAllowanceSummary(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentLeft: 57,
            currentResetAt: date(9, 21, 2, 0),
            weeklyPercentLeft: nil,
            weeklyResetAt: nil,
            fetchedAt: date(9, 20, 22, 58)
        )
        let window = summary.windows(asOf: date(9, 21, 9, 58)).first
        XCTAssertEqual(window?.percentLeft, 100)
        XCTAssertNil(window?.resetAt)
        XCTAssertEqual(window?.isDerived, true)
    }
}
