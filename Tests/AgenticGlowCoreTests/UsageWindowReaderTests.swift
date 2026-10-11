import Foundation
import XCTest
@testable import AgenticGlowCore

final class UsageWindowReaderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testFreshAllowanceReportsBothWindows() {
        let observations = UsageWindowReader.observations(
            provider: .codex,
            state: .available(allowance(currentUsed: 100, weeklyUsed: 40), .fresh),
            now: now
        )

        XCTAssertEqual(observations.map(\.key.windowLabel), ["5h", UsageWindowKey.weeklyLabel])
        XCTAssertEqual(observations.map(\.availability), [.exhausted, .available])
    }

    func testStaleAllowanceIsNeverProofOfAvailability() {
        // A stale value is the last successful fetch replayed after a
        // failure. Reading it as live is how a network blip could fake a
        // reset, so every window must observe as unknown.
        let observations = UsageWindowReader.observations(
            provider: .claude,
            state: .available(allowance(currentUsed: 0, weeklyUsed: 0), .stale),
            now: now
        )

        XCTAssertEqual(observations.count, 2)
        XCTAssertTrue(observations.allSatisfy { $0.availability == .unknown })
    }

    func testUnavailableAndOffProduceNoObservations() {
        XCTAssertEqual(
            UsageWindowReader.observations(provider: .codex, state: .unavailable("nope"), now: now),
            []
        )
        XCTAssertEqual(
            UsageWindowReader.observations(provider: .codex, state: .off, now: now),
            []
        )
        XCTAssertEqual(
            UsageWindowReader.observations(provider: .codex, state: .loading, now: now),
            []
        )
    }

    func testAvailabilityThresholds() {
        XCTAssertEqual(UsageWindowReader.availability(forPercentLeft: nil), .unknown)
        XCTAssertEqual(UsageWindowReader.availability(forPercentLeft: 0), .exhausted)
        XCTAssertEqual(UsageWindowReader.availability(forPercentLeft: 5), .approachingLimit)
        XCTAssertEqual(
            UsageWindowReader.availability(
                forPercentLeft: AllowanceWarning.thresholdPercentLeft
            ),
            .available
        )
        XCTAssertEqual(UsageWindowReader.availability(forPercentLeft: 100), .available)
    }

    func testMissingWeeklyWindowIsOmittedRatherThanGuessed() {
        let observations = UsageWindowReader.observations(
            provider: .codex,
            state: .available(allowance(currentUsed: 100, weeklyUsed: nil), .fresh),
            now: now
        )

        XCTAssertEqual(observations.map(\.key.windowLabel), ["5h"])
    }

    func testSpokenWindowNames() {
        XCTAssertEqual(
            UsageWindowKey(provider: .codex, windowLabel: "5h").spokenWindowName,
            "5-hour"
        )
        XCTAssertEqual(
            UsageWindowKey(provider: .codex, windowLabel: UsageWindowKey.weeklyLabel).spokenWindowName,
            "weekly"
        )
        XCTAssertEqual(
            UsageWindowKey(provider: .codex, windowLabel: "Weekly").spokenWindowName,
            "weekly"
        )
        XCTAssertEqual(
            UsageWindowKey(provider: .codex, windowLabel: "Current").spokenWindowName,
            "current"
        )
    }

    private func allowance(currentUsed: Double?, weeklyUsed: Double?) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentUsed,
            currentResetAt: now.addingTimeInterval(600),
            weeklyPercentUsed: weeklyUsed,
            weeklyResetAt: now.addingTimeInterval(86_400),
            fetchedAt: now
        )
    }
}
