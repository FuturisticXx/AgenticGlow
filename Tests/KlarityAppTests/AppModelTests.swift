import XCTest
@testable import Klarity
@testable import KlarityCore

@MainActor
final class AppModelTests: XCTestCase {
    func testRefreshLoadsAndResolvesMultipleSessions() throws {
        let store = InMemorySessionStore(events: [
            .testEvent(
                provider: .codex,
                phase: .thinking,
                turnStartedAt: Date(timeIntervalSince1970: 90)
            ),
            .testEvent(
                provider: .claude,
                phase: .permission,
                turnStartedAt: Date(timeIntervalSince1970: 80)
            )
        ])
        let model = AppModel(
            store: store,
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            now: { Date(timeIntervalSince1970: 100) }
        )

        model.refresh()

        XCTAssertEqual(model.resolved.sessions.count, 2)
        XCTAssertEqual(model.resolved.dominantPhase, .permission)
    }

    func testRefreshRemovesEventsPastFileRetention() throws {
        let now = Date(timeIntervalSince1970: 200_000)
        let event = NormalizedEvent(
            schemaVersion: 1,
            provider: .codex,
            surface: .cli,
            sessionID: "expired-session",
            turnID: "turn",
            phase: .thinking,
            label: "Thinking",
            toolCategory: nil,
            projectName: "Klarity",
            workingDirectory: "/tmp/Klarity",
            sourceBundleID: "com.apple.Terminal",
            sourceProcessID: 123,
            sourceProcessStartedAt: nil,
            turnStartedAt: now.addingTimeInterval(-100),
            updatedAt: now.addingTimeInterval(-SessionResolver.fileRetention - 1)
        )
        let store = InMemorySessionStore(events: [event])
        let model = AppModel(
            store: store,
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            now: { now }
        )

        model.refresh()

        XCTAssertTrue(store.events.isEmpty)
        XCTAssertTrue(model.resolved.sessions.isEmpty)
    }

    func testActivateRoutesTheSessionBundleIdentifier() {
        let activator = RecordingActivator()
        let model = AppModel(
            store: InMemorySessionStore(events: []),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: activator
        )
        let session = SessionSnapshot(
            provider: .claude,
            surface: .desktop,
            sessionID: "session",
            phase: .permission,
            label: "Permission required",
            projectName: "Klarity",
            sourceBundleID: "com.anthropic.claudefordesktop",
            elapsedSeconds: 5,
            updatedAt: Date()
        )

        model.activate(session)

        XCTAssertEqual(activator.bundleIdentifiers, ["com.anthropic.claudefordesktop"])
    }

    func testRefreshReportsStoreLoadFailure() {
        let model = AppModel(
            store: FailingSessionStore(),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator()
        )

        model.refresh()

        XCTAssertEqual(model.storeErrorDescription, "loadFailed")
        XCTAssertTrue(model.resolved.sessions.isEmpty)
    }
}

private final class InMemorySessionStore: SessionStateStoring {
    var events: [NormalizedEvent]

    init(events: [NormalizedEvent]) {
        self.events = events
    }

    func write(_ event: NormalizedEvent) {
        events.removeAll { SessionKey($0) == SessionKey(event) }
        events.append(event)
    }

    func loadAll() -> [NormalizedEvent] {
        events
    }

    func load(_ key: SessionKey) -> NormalizedEvent? {
        events.first { SessionKey($0) == key }
    }

    func remove(_ key: SessionKey) {
        events.removeAll { SessionKey($0) == key }
    }
}

private struct AlwaysAliveProcessMonitor: ProcessMonitoring {
    func isAlive(processID: Int32, startedAt: Date?) -> Bool {
        true
    }
}

private struct FailingSessionStore: SessionStateStoring {
    enum Failure: Error {
        case loadFailed
    }

    func write(_ event: NormalizedEvent) throws {}
    func loadAll() throws -> [NormalizedEvent] { throw Failure.loadFailed }
    func load(_ key: SessionKey) throws -> NormalizedEvent? { nil }
    func remove(_ key: SessionKey) throws {}
}

private final class RecordingActivator: ApplicationActivating, @unchecked Sendable {
    private(set) var bundleIdentifiers: [String?] = []

    func activate(bundleIdentifier: String?) -> Bool {
        bundleIdentifiers.append(bundleIdentifier)
        return true
    }
}
