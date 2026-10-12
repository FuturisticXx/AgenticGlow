import Foundation
import XCTest
@testable import AgenticGlowCore

final class SyncFreshnessTests: XCTestCase {
    private let observedAt = Date(timeIntervalSince1970: 1_783_099_000)

    func testThresholdsDeriveFromTheDesktopWidgetAndTheHeartbeat() {
        XCTAssertEqual(SyncFreshness.staleThreshold, WidgetDataFreshness.staleThreshold)
        XCTAssertEqual(SyncFreshness.heartbeatInterval, AllowanceRefreshPolicy.idleInterval)
        XCTAssertEqual(SyncFreshness.staleThreshold, 3 * SyncFreshness.heartbeatInterval)
        XCTAssertEqual(SyncFreshness.offlineThreshold, 12 * SyncFreshness.heartbeatInterval)
    }

    func testFreshUntilTheStaleThreshold() {
        XCTAssertEqual(SyncFreshness.evaluate(observedAt: observedAt, now: observedAt), .fresh(age: 0))
        let atThreshold = observedAt.addingTimeInterval(SyncFreshness.staleThreshold)
        XCTAssertTrue(SyncFreshness.evaluate(observedAt: observedAt, now: atThreshold).isFresh)
    }

    func testStaleBetweenTheThresholds() {
        let now = observedAt.addingTimeInterval(SyncFreshness.staleThreshold + 1)
        XCTAssertEqual(SyncFreshness.evaluate(observedAt: observedAt, now: now), .stale(age: SyncFreshness.staleThreshold + 1))
    }

    func testOfflineBeyondTheOfflineThreshold() {
        let now = observedAt.addingTimeInterval(SyncFreshness.offlineThreshold + 1)
        XCTAssertTrue(SyncFreshness.evaluate(observedAt: observedAt, now: now).isOffline)
    }

    func testAClockAheadOfThePhoneReadsAsJustNow() {
        let now = observedAt.addingTimeInterval(-120)
        XCTAssertEqual(SyncFreshness.evaluate(observedAt: observedAt, now: now), .fresh(age: 0))
    }

    func testTransitionsAreTheRemainingBoundaries() {
        let transitions = SyncFreshness.transitions(after: observedAt, now: observedAt)
        XCTAssertEqual(
            transitions,
            [observedAt.addingTimeInterval(15 * 60 + 1), observedAt.addingTimeInterval(60 * 60 + 1)]
        )
        // An entry rendered at each transition really is in the next state.
        XCTAssertEqual(SyncFreshness.evaluate(observedAt: observedAt, now: transitions[0]), .stale(age: 15 * 60 + 1))
        XCTAssertTrue(SyncFreshness.evaluate(observedAt: observedAt, now: transitions[1]).isOffline)
        let halfway = observedAt.addingTimeInterval(30 * 60)
        XCTAssertEqual(SyncFreshness.transitions(after: observedAt, now: halfway), [observedAt.addingTimeInterval(60 * 60 + 1)])
        XCTAssertEqual(SyncFreshness.transitions(after: observedAt, now: observedAt.addingTimeInterval(2 * 3600)), [])
    }

    func testPublishingPolicyPublishesOnChangeOrHeartbeat() {
        XCTAssertTrue(SyncPublishingPolicy.shouldPublish(changed: true, lastPublishedAt: observedAt, now: observedAt))
        XCTAssertTrue(SyncPublishingPolicy.shouldPublish(changed: false, lastPublishedAt: nil, now: observedAt))
        XCTAssertFalse(SyncPublishingPolicy.shouldPublish(
            changed: false,
            lastPublishedAt: observedAt,
            now: observedAt.addingTimeInterval(SyncFreshness.heartbeatInterval - 1)
        ))
        XCTAssertTrue(SyncPublishingPolicy.shouldPublish(
            changed: false,
            lastPublishedAt: observedAt,
            now: observedAt.addingTimeInterval(SyncFreshness.heartbeatInterval)
        ))
    }

    func testFooterCopyNamesTheMacAndTheAge() {
        let provenance = WidgetSyncProvenance(sourceMacName: "MacBook Pro", observedAt: observedAt)
        XCTAssertEqual(provenance.footer(now: observedAt.addingTimeInterval(30)), "MacBook Pro · Just now")
        XCTAssertEqual(provenance.footer(now: observedAt.addingTimeInterval(3 * 60)), "MacBook Pro · 3m ago")
        XCTAssertEqual(provenance.footer(now: observedAt.addingTimeInterval(32 * 60)), "MacBook Pro · Updated 32m ago")
        XCTAssertEqual(
            provenance.footer(now: observedAt.addingTimeInterval(3 * 3600)),
            "MacBook Pro unavailable · last seen 3h ago"
        )
        XCTAssertEqual(
            provenance.footer(now: observedAt.addingTimeInterval(2 * 86_400 + 3600)),
            "MacBook Pro unavailable · last seen 2d ago"
        )
    }

    func testLastUpdatedLabelCountsDaysPastADay() {
        XCTAssertEqual(WidgetSnapshotFormatting.lastUpdatedLabel(observedAt, now: observedAt.addingTimeInterval(23 * 3600)), "23h ago")
        XCTAssertEqual(WidgetSnapshotFormatting.lastUpdatedLabel(observedAt, now: observedAt.addingTimeInterval(49 * 3600)), "2d ago")
    }

    func testProvenanceFromEnvelope() {
        let snapshot = WidgetSnapshot(generatedAt: observedAt, sessions: [], allowances: [], providers: [], attentionCount: 0, activeCount: 0)
        let envelope = SyncedStateEnvelope(sourceMacID: UUID().uuidString, sourceMacName: "Studio", observedAt: observedAt, snapshot: snapshot)
        let provenance = WidgetSyncProvenance(envelope)
        XCTAssertEqual(provenance.sourceMacName, "Studio")
        XCTAssertEqual(provenance.observedAt, observedAt)
        XCTAssertEqual(SyncedStateLoadResult.loaded(envelope).snapshotLoadResult, .loaded(snapshot))
        XCTAssertEqual(SyncedStateLoadResult.corrupted.snapshotLoadResult, .corrupted)
    }
}

final class SyncedStateWireFidelityTests: XCTestCase {
    /// A fractional `Date` does not survive the seconds-since-1970 wire
    /// format bit-for-bit; the envelope floors `observedAt` so it does.
    func testObservedAtSurvivesTheWireExactly() throws {
        let fractional = Date(timeIntervalSince1970: 1_789_732_291.3184168)
        let snapshot = WidgetSnapshot(generatedAt: fractional, sessions: [], allowances: [], providers: [], attentionCount: 0, activeCount: 0)
        let envelope = SyncedStateEnvelope(sourceMacID: UUID().uuidString, sourceMacName: "Mac", observedAt: fractional, snapshot: snapshot)
        XCTAssertEqual(envelope.observedAt, Date(timeIntervalSince1970: 1_789_732_291))
        let decoded = try SyncedStateCodec.decode(try SyncedStateCodec.encode(envelope))
        XCTAssertEqual(decoded.observedAt, envelope.observedAt)
        XCTAssertEqual(decoded.sourceMacID, envelope.sourceMacID)
        // The snapshot's own dates are compared through the wire on both
        // sides, which is what the round-trip verifier does.
        let twice = try SyncedStateCodec.decode(try SyncedStateCodec.encode(decoded))
        XCTAssertEqual(twice, decoded)
    }
}

final class SyncFreshnessSummaryTests: XCTestCase {
    func testSummaryNamesTheStateAndAge() {
        XCTAssertEqual(SyncFreshness.fresh(age: 3 * 60).summary, "fresh (3m)")
        XCTAssertEqual(SyncFreshness.stale(age: 32 * 60).summary, "stale (32m)")
        XCTAssertEqual(SyncFreshness.offline(age: 3 * 3600 + 5 * 60).summary, "offline (3h 5m)")
        XCTAssertEqual(SyncFreshness.offline(age: 39 * 3600).summary, "offline (1d 15h)")
    }
}
