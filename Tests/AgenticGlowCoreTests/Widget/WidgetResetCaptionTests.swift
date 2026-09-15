import Foundation
import XCTest
@testable import AgenticGlowCore

/// Regression cover for the reset caption truncating beside the
/// low-allowance warning icon:
/// "5h resets in 3h 27m left (Mon, Sep 7 at 12:16 A...".
///
/// The caption is composed rather than measured here; the width it has to
/// fit into is a rendering concern, so what these tests hold is that the
/// composed string stays short and keeps every piece of information.
final class WidgetResetCaptionTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }()

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    func testTheCaptionThatTruncatedIsNowShorterAndStillComplete() throws {
        let now = date("2026-09-06T20:49:00-05:00")
        let reset = date("2026-09-07T00:16:00-05:00")

        let detail = WidgetSnapshotFormatting.captionResetDetail(reset, now: now, calendar: calendar)

        let caption = "5h resets \(try XCTUnwrap(detail))"
        XCTAssertLessThan(
            caption.count,
            "5h resets in 3h 27m left (Mon, Sep 7 at 12:16 AM)".count,
            "The caption must be shorter than the one that truncated"
        )
        // Nothing semantic was dropped.
        XCTAssertTrue(caption.contains("3h 27m"), caption)
        XCTAssertTrue(caption.contains("Sun") || caption.contains("Mon"), caption)
        XCTAssertTrue(caption.contains("Sep 7"), caption)
        XCTAssertTrue(caption.contains("12:16"), caption)
    }

    func testTheCountdownNoLongerSaysTheSameThingTwice() throws {
        let now = date("2026-09-06T20:49:00-05:00")
        let reset = date("2026-09-07T00:16:00-05:00")

        let detail = try XCTUnwrap(
            WidgetSnapshotFormatting.captionResetDetail(reset, now: now, calendar: calendar)
        )

        XCTAssertTrue(detail.hasPrefix("in "), detail)
        XCTAssertFalse(detail.contains("left"), "\"in 3h 27m left\" said it twice")
    }

    func testASameDayResetKeepsJustTheClockTime() throws {
        let now = date("2026-09-06T13:00:00-05:00")
        let reset = date("2026-09-06T17:30:00-05:00")

        let detail = WidgetSnapshotFormatting.captionResetDetail(reset, now: now, calendar: calendar)

        XCTAssertEqual(detail?.contains("Sep"), false, "Today needs no date")
        XCTAssertEqual(detail?.hasPrefix("in "), true)
    }

    func testANextDayResetKeepsItsWeekdayAndDate() throws {
        let now = date("2026-09-06T20:00:00-05:00")
        let reset = date("2026-09-07T02:00:00-05:00")

        let detail = try XCTUnwrap(
            WidgetSnapshotFormatting.captionResetDetail(reset, now: now, calendar: calendar)
        )

        XCTAssertTrue(detail.contains("Sep 7"), detail)
        XCTAssertTrue(detail.contains("·"), "The separator replaces the word \"at\"")
    }

    /// Past the countdown horizon the date stands alone, as before.
    func testAWeeklyResetDropsTheCountdownAndKeepsTheDate() throws {
        let now = date("2026-09-06T20:00:00-05:00")
        let reset = date("2026-09-13T19:16:00-05:00")

        let detail = try XCTUnwrap(
            WidgetSnapshotFormatting.captionResetDetail(reset, now: now, calendar: calendar)
        )

        XCTAssertFalse(detail.hasPrefix("in "), detail)
        XCTAssertTrue(detail.contains("Sep 13"), detail)
        XCTAssertTrue(detail.contains("7:16") || detail.contains("19:16"), detail)
    }

    func testAMissingResetProducesNoDetail() {
        XCTAssertNil(
            WidgetSnapshotFormatting.captionResetDetail(nil, now: Date(), calendar: calendar)
        )
    }

    /// The popover's own wording is untouched; only the widget caption
    /// was too wide.
    func testThePopoverPhrasingIsUnchanged() throws {
        let now = date("2026-09-06T20:49:00-05:00")
        let reset = date("2026-09-07T00:16:00-05:00")

        XCTAssertEqual(WidgetSnapshotFormatting.relativeResetLabel(reset, now: now), "3h 27m left")
        let absolute = try XCTUnwrap(
            WidgetSnapshotFormatting.absoluteResetLabel(reset, now: now, calendar: calendar)
        )
        XCTAssertTrue(absolute.contains("at"), absolute)
    }

    func testTheCountdownLabelDropsOnlyItsTrailingWord() {
        let now = date("2026-09-06T20:49:00-05:00")

        XCTAssertEqual(
            WidgetSnapshotFormatting.countdownLabel(date("2026-09-06T21:19:00-05:00"), now: now),
            "30m"
        )
        XCTAssertEqual(
            WidgetSnapshotFormatting.countdownLabel(date("2026-09-06T23:49:00-05:00"), now: now),
            "3h"
        )
        XCTAssertNil(WidgetSnapshotFormatting.countdownLabel(nil, now: now))
    }
}
