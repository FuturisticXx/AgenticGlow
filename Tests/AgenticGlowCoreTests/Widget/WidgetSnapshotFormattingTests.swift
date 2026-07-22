import Foundation
import XCTest
@testable import AgenticGlowCore

final class WidgetSnapshotFormattingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - Percent

    func testPercentLeftLabelRoundsToInt() {
        XCTAssertEqual(WidgetSnapshotFormatting.percentLeftLabel(71.6), "72% left")
    }

    func testPercentLeftLabelNilIsUnavailable() {
        XCTAssertEqual(WidgetSnapshotFormatting.percentLeftLabel(nil), "Unavailable")
    }

    // MARK: - Elapsed

    func testElapsedUnderOneMinuteShowsExactSeconds() {
        XCTAssertEqual(WidgetSnapshotFormatting.elapsedLabel(seconds: 54), "54s")
    }

    func testElapsedUnderOneHourShowsMinutes() {
        XCTAssertEqual(WidgetSnapshotFormatting.elapsedLabel(seconds: 125), "2m")
    }

    func testElapsedOverOneHourShowsHoursAndMinutes() {
        XCTAssertEqual(WidgetSnapshotFormatting.elapsedLabel(seconds: 3900), "1h 5m")
    }

    func testElapsedExactHourOmitsZeroMinutes() {
        XCTAssertEqual(WidgetSnapshotFormatting.elapsedLabel(seconds: 7200), "2h")
    }

    func testElapsedNilIsNil() {
        XCTAssertNil(WidgetSnapshotFormatting.elapsedLabel(seconds: nil))
    }

    // MARK: - Relative reset

    func testRelativeResetUnderAnHour() {
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(
            WidgetSnapshotFormatting.relativeResetLabel(now.addingTimeInterval(25 * 60), now: now),
            "25m left"
        )
    }

    func testRelativeResetOverAnHour() {
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(
            WidgetSnapshotFormatting.relativeResetLabel(now.addingTimeInterval(2 * 3600 + 15 * 60), now: now),
            "2h 15m left"
        )
    }

    func testRelativeResetInThePastReadsAsResetting() {
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(
            WidgetSnapshotFormatting.relativeResetLabel(now.addingTimeInterval(-60), now: now),
            "Resetting"
        )
    }

    func testRelativeResetNilIsNil() {
        XCTAssertNil(WidgetSnapshotFormatting.relativeResetLabel(nil, now: Date()))
    }

    // MARK: - Absolute reset

    func testAbsoluteResetSameDayShowsTimeOnly() {
        let now = date(2026, 7, 20, 10, 0)
        let resetAt = date(2026, 7, 20, 15, 30)
        XCTAssertEqual(
            WidgetSnapshotFormatting.absoluteResetLabel(resetAt, now: now, calendar: calendar),
            resetAt.formatted(.dateTime.hour().minute())
        )
    }

    func testAbsoluteResetDifferentDayIncludesDate() {
        let now = date(2026, 7, 20, 10, 0)
        let resetAt = date(2026, 7, 24, 15, 30)
        let label = WidgetSnapshotFormatting.absoluteResetLabel(resetAt, now: now, calendar: calendar)
        XCTAssertEqual(
            label,
            resetAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        )
    }

    func testAbsoluteResetNilIsNil() {
        XCTAssertNil(WidgetSnapshotFormatting.absoluteResetLabel(nil, now: Date(), calendar: calendar))
    }

    // MARK: - Last updated

    func testLastUpdatedJustNow() {
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(WidgetSnapshotFormatting.lastUpdatedLabel(now.addingTimeInterval(-5), now: now), "Just now")
    }

    func testLastUpdatedMinutesAgo() {
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(WidgetSnapshotFormatting.lastUpdatedLabel(now.addingTimeInterval(-300), now: now), "5m ago")
    }

    func testLastUpdatedHoursAgo() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(WidgetSnapshotFormatting.lastUpdatedLabel(now.addingTimeInterval(-7500), now: now), "2h ago")
    }

    // MARK: - Fixtures

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
