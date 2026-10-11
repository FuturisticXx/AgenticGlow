import Foundation
import XCTest
@testable import AgenticGlowCore

final class UsageResetDetectorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)
    private let key = UsageWindowKey(provider: .codex, windowLabel: "5h")

    // MARK: Transition matrix

    func testAvailableToAvailableDoesNotNotify() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.available)])
        XCTAssertEqual(detector.evaluate([observation(.available)]), [])
    }

    func testAvailableToExhaustedDoesNotNotify() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.available)])
        XCTAssertEqual(detector.evaluate([observation(.exhausted)]), [])
    }

    func testExhaustedToExhaustedDoesNotNotify() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted)])
        XCTAssertEqual(detector.evaluate([observation(.exhausted)]), [])
    }

    func testExhaustedToAvailableNotifiesOnce() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted)])

        let events = detector.evaluate([observation(.available, percentLeft: 100)])
        XCTAssertEqual(events.map(\.key), [key])
        XCTAssertEqual(events.first?.percentLeft, 100)

        // Usage simply staying available must never repeat the alert.
        XCTAssertEqual(detector.evaluate([observation(.available, percentLeft: 99)]), [])
        XCTAssertEqual(detector.evaluate([observation(.available, percentLeft: 98)]), [])
    }

    func testUnknownToAvailableDoesNotNotify() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.unknown)])
        XCTAssertEqual(detector.evaluate([observation(.available)]), [])
    }

    func testFirstEverObservationOfAvailableDoesNotNotify() {
        var detector = UsageResetDetector()
        XCTAssertEqual(detector.evaluate([observation(.available)]), [])
    }

    func testExhaustedThenUnknownThenAvailableStillNotifies() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted)])
        // A failed fetch, a stale cache, or a network drop: none of these
        // may erase the knowledge that the window was exhausted.
        _ = detector.evaluate([observation(.unknown)])
        _ = detector.evaluate([observation(.unknown)])

        XCTAssertEqual(detector.evaluate([observation(.available)]).map(\.key), [key])
    }

    func testPartialReturnCountsAsAReset() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted)])
        XCTAssertEqual(
            detector.evaluate([observation(.approachingLimit, percentLeft: 4)]).map(\.key),
            [key]
        )
    }

    // MARK: Robustness

    func testDuplicateObservationsInOneRoundNotifyOnce() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted)])
        let events = detector.evaluate([observation(.available), observation(.available)])
        XCTAssertEqual(events.count, 1)
    }

    func testSimultaneousProviderResetsAreIndependent() {
        let claudeKey = UsageWindowKey(provider: .claude, windowLabel: "5h")
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted), observation(.exhausted, key: claudeKey)])

        let events = detector.evaluate([
            observation(.available),
            observation(.available, key: claudeKey)
        ])
        XCTAssertEqual(Set(events.map(\.key)), [key, claudeKey])
    }

    func testWindowsOfOneProviderAreTrackedSeparately() {
        let weekly = UsageWindowKey(provider: .codex, windowLabel: UsageWindowKey.weeklyLabel)
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted), observation(.available, key: weekly)])

        let events = detector.evaluate([observation(.available), observation(.available, key: weekly)])
        XCTAssertEqual(events.map(\.key), [key])
    }

    func testRenamedWindowStartsFreshAndStaysQuiet() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted)])
        // Codex relabels a window when the account's plan changes. The new
        // label is a new window with no history, so it must not fire.
        let renamed = UsageWindowKey(provider: .codex, windowLabel: "Weekly")
        XCTAssertEqual(detector.evaluate([observation(.available, key: renamed)]), [])
    }

    func testForgettingAProviderClearsItsEvidenceOnly() {
        let claudeKey = UsageWindowKey(provider: .claude, windowLabel: "5h")
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted), observation(.exhausted, key: claudeKey)])

        detector.forget(provider: .codex)

        let events = detector.evaluate([
            observation(.available),
            observation(.available, key: claudeKey)
        ])
        XCTAssertEqual(events.map(\.key), [claudeKey])
    }

    func testClockGoingBackwardsDoesNotAffectDetection() {
        var detector = UsageResetDetector()
        _ = detector.evaluate([observation(.exhausted)])
        let backwards = observation(.available, observedAt: now.addingTimeInterval(-86_400))
        XCTAssertEqual(detector.evaluate([backwards]).map(\.key), [key])
    }

    // MARK: Restart

    func testRestartWithPersistedExhaustionStillNotifiesOnce() {
        var before = UsageResetDetector()
        _ = before.evaluate([observation(.exhausted)])

        var afterRestart = UsageResetDetector(evidence: before.evidence)
        XCTAssertEqual(afterRestart.evaluate([observation(.available)]).map(\.key), [key])
    }

    func testRestartAfterAlertDoesNotNotifyAgain() {
        var before = UsageResetDetector()
        _ = before.evaluate([observation(.exhausted)])
        XCTAssertEqual(before.evaluate([observation(.available)]).count, 1)

        var afterRestart = UsageResetDetector(evidence: before.evidence)
        XCTAssertEqual(afterRestart.evaluate([observation(.available)]), [])
    }

    func testRestartWithNoPersistedEvidenceStaysQuiet() {
        var detector = UsageResetDetector(evidence: [:])
        XCTAssertEqual(detector.evaluate([observation(.available)]), [])
    }

    private func observation(
        _ availability: UsageAvailability,
        key: UsageWindowKey? = nil,
        percentLeft: Double? = nil,
        observedAt: Date? = nil
    ) -> UsageWindowObservation {
        UsageWindowObservation(
            key: key ?? self.key,
            availability: availability,
            percentLeft: percentLeft,
            expectedReset: nil,
            observedAt: observedAt ?? now
        )
    }
}
