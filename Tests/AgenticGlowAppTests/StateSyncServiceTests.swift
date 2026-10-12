import XCTest
import AgenticGlowCore
@testable import AgenticGlow

@MainActor
final class StateSyncServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)
    private let identity = MacSyncIdentity(sourceMacID: UUID().uuidString, sourceMacName: "Test Mac")

    private func makeSnapshot(activeCount: Int = 1) -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: now, sessions: [], allowances: [], providers: [], attentionCount: 0, activeCount: activeCount)
    }

    /// Publishing hops through a Task. Yield until it has landed, with a
    /// bound so a hang fails rather than waits forever; a fixed handful of
    /// yields was flaky under load.
    private func settle(until condition: @escaping () -> Bool = { true }) async {
        for _ in 0..<200 {
            for _ in 0..<5 { await Task.yield() }
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    func testPreferenceDefaultsOff() {
        let suiteName = "StateSyncServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)
        XCTAssertFalse(preferences.iPhoneSyncEnabled)
        preferences.iPhoneSyncEnabled = true
        XCTAssertTrue(defaults.bool(forKey: "iPhoneSyncEnabled"))
        XCTAssertTrue(PreferencesStore(defaults: defaults).iPhoneSyncEnabled)
    }

    func testIdentityIsAStoredRandomUUIDNotAHardwareIdentifier() {
        let suiteName = "StateSyncServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = MacSyncIdentity.stored(in: defaults)
        XCTAssertNotNil(UUID(uuidString: first.sourceMacID))
        XCTAssertEqual(MacSyncIdentity.stored(in: defaults).sourceMacID, first.sourceMacID, "minted once")
        defaults.set("C02XYZ", forKey: MacSyncIdentity.defaultsKey)
        XCTAssertNotEqual(MacSyncIdentity.stored(in: defaults).sourceMacID, "C02XYZ", "a non-UUID value is replaced")
        XCTAssertFalse(first.sourceMacName.isEmpty)
    }

    func testNothingIsPublishedWhileOff() async {
        let transport = RecordingTransport()
        let service = StateSyncService(transport: transport, identity: identity, isEnabled: { false })
        service.snapshotDidRefresh(makeSnapshot(), now: now)
        await settle()
        XCTAssertEqual(transport.published.count, 0)
        XCTAssertEqual(service.status, "Off")
    }

    func testNothingIsPublishedWithoutAnEntitledTransport() async {
        let service = StateSyncService(transport: nil, identity: identity, isEnabled: { true })
        service.snapshotDidRefresh(makeSnapshot(), now: now)
        await settle()
        XCTAssertFalse(service.isAvailable)
        XCTAssertEqual(service.status, "This build is not signed for iCloud")
    }

    func testPublishesOnceOnChangeAndAgainOnTheHeartbeat() async {
        let transport = RecordingTransport()
        let service = StateSyncService(transport: transport, identity: identity, isEnabled: { true })

        service.snapshotDidRefresh(makeSnapshot(), now: now)
        await settle { transport.published.count == 1 }
        XCTAssertEqual(transport.published.count, 1)
        XCTAssertEqual(transport.published.first?.sourceMacID, identity.sourceMacID)
        XCTAssertEqual(transport.published.first?.sourceMacName, "Test Mac")
        XCTAssertEqual(transport.published.first?.observedAt, now)

        // Unchanged, inside the heartbeat: nothing.
        service.snapshotDidRefresh(makeSnapshot(), now: now.addingTimeInterval(2))
        await settle()
        XCTAssertEqual(transport.published.count, 1)

        // Changed: published, with the observation time of that tick.
        let changedAt = now.addingTimeInterval(4)
        service.snapshotDidRefresh(makeSnapshot(activeCount: 2), now: changedAt)
        await settle { transport.published.count == 2 }
        XCTAssertEqual(transport.published.count, 2)
        XCTAssertEqual(transport.published.last?.observedAt, changedAt)
        XCTAssertEqual(transport.published.last?.snapshot.activeCount, 2)

        // Unchanged, but a heartbeat is due: published so the phone can
        // tell a quiet Mac from a missing one.
        let heartbeatAt = changedAt.addingTimeInterval(SyncFreshness.heartbeatInterval)
        service.snapshotDidRefresh(makeSnapshot(activeCount: 2), now: heartbeatAt)
        await settle { transport.published.count == 3 }
        XCTAssertEqual(transport.published.count, 3)
        XCTAssertEqual(transport.published.last?.observedAt, heartbeatAt)
        XCTAssertTrue(service.status.hasPrefix("Published"))
    }

    func testAFailedPublishWaitsBeforeRetrying() async {
        let transport = RecordingTransport(failing: true)
        let service = StateSyncService(transport: transport, identity: identity, isEnabled: { true })
        service.snapshotDidRefresh(makeSnapshot(), now: now)
        await settle { service.status.hasPrefix("Not published") }
        XCTAssertEqual(transport.attempts, 1)
        XCTAssertTrue(service.status.hasPrefix("Not published"))

        service.snapshotDidRefresh(makeSnapshot(activeCount: 2), now: now.addingTimeInterval(2))
        await settle()
        XCTAssertEqual(transport.attempts, 1, "retry waits out the interval even for a change")

        transport.failing = false
        service.snapshotDidRefresh(makeSnapshot(activeCount: 2), now: now.addingTimeInterval(StateSyncService.retryInterval))
        await settle { transport.published.count == 1 }
        XCTAssertEqual(transport.attempts, 2)
        XCTAssertEqual(transport.published.count, 1)
    }

    func testTurningSyncOffStopsPublishingImmediately() async {
        let transport = RecordingTransport()
        var enabled = true
        let service = StateSyncService(transport: transport, identity: identity, isEnabled: { enabled })
        service.snapshotDidRefresh(makeSnapshot(), now: now)
        await settle { transport.published.count == 1 }
        XCTAssertEqual(transport.published.count, 1)

        enabled = false
        service.snapshotDidRefresh(makeSnapshot(activeCount: 5), now: now.addingTimeInterval(3600))
        await settle()
        XCTAssertEqual(transport.published.count, 1)
        XCTAssertEqual(service.status, "Off")
    }
}

private final class RecordingTransport: SyncedStatePublishing, @unchecked Sendable {
    private(set) var published: [SyncedStateEnvelope] = []
    private(set) var attempts = 0
    var failing: Bool

    init(failing: Bool = false) {
        self.failing = failing
    }

    struct Failure: LocalizedError {
        var errorDescription: String? { "iCloud is unavailable" }
    }

    func publish(_ envelope: SyncedStateEnvelope) async throws {
        attempts += 1
        if failing { throw Failure() }
        published.append(envelope)
    }
}
