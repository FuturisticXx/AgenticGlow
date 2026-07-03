import AppKit
import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

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
            projectName: "AgenticGlow",
            workingDirectory: "/tmp/AgenticGlow",
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
            projectName: "AgenticGlow",
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

    func testRefreshFailsClosedAfterStoreLoadFailure() {
        let store = FailingAfterFirstLoadStore(events: [
            .testEvent(
                provider: .codex,
                phase: .thinking,
                turnStartedAt: Date(timeIntervalSince1970: 90)
            )
        ])
        let model = AppModel(
            store: store,
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            now: { Date(timeIntervalSince1970: 120) }
        )
        model.refresh()
        XCTAssertEqual(model.resolved.dominantPhase, .thinking)

        model.refresh()

        XCTAssertEqual(model.storeErrorDescription, "loadFailed")
        XCTAssertEqual(model.resolved.dominantPhase, .idle)
        XCTAssertTrue(model.resolved.sessions.isEmpty)
        XCTAssertEqual(model.resolved.activeCount, 0)
        XCTAssertEqual(model.resolved.permissionCount, 0)
    }

    func testStoreFailureProvidesSessionDataErrorPresentation() {
        let model = AppModel(
            store: FailingSessionStore(),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator()
        )

        model.refresh()

        XCTAssertEqual(model.sessionDataErrorPresentation?.title, "Session data unavailable")
        XCTAssertEqual(
            model.sessionDataErrorPresentation?.message,
            "Check Integrations and try again."
        )
    }

    func testProviderUsageCanBeEnabledAndDisabledIndependently() async {
        let cache = AppModelAllowanceCache()
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [AppModelAllowanceAdapter(provider: .codex)],
            cache: cache
        )
        let model = AppModel(
            store: InMemorySessionStore(events: []),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            allowanceCoordinator: coordinator
        )

        await model.setUsageEnabled(true, provider: .codex)

        guard case let .available(value, freshness) = model.allowanceState(for: .codex) else {
            return XCTFail("Expected Codex allowance")
        }
        XCTAssertEqual(value.currentPercentLeft, 75)
        XCTAssertEqual(freshness, .fresh)
        XCTAssertEqual(model.allowanceState(for: .claude), .off)

        await model.setUsageEnabled(false, provider: .codex)
        XCTAssertEqual(model.allowanceState(for: .codex), .off)
    }

    func testReduceMotionObserverUpdatesModelAndDisablesActiveAnimation() {
        let center = NotificationCenter()
        var reduceMotionEnabled = false
        let model = AppModel(
            store: InMemorySessionStore(events: [
                .testEvent(
                    provider: .codex,
                    phase: .thinking,
                    turnStartedAt: Date(timeIntervalSince1970: 90)
                )
            ]),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            now: { Date(timeIntervalSince1970: 120) }
        )
        model.refresh()
        let observer = ReduceMotionObserver(
            model: model,
            notificationCenter: center,
            reduceMotionEnabled: { reduceMotionEnabled }
        )
        observer.start()
        XCTAssertTrue(statusPresentation(for: model).animates)

        reduceMotionEnabled = true
        center.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)

        XCTAssertTrue(model.reduceMotion)
        XCTAssertFalse(statusPresentation(for: model).animates)
    }

    func testReduceMotionObserverStopsListening() {
        let center = NotificationCenter()
        var reduceMotionEnabled = false
        let model = AppModel(
            store: InMemorySessionStore(events: []),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator()
        )
        let observer = ReduceMotionObserver(
            model: model,
            notificationCenter: center,
            reduceMotionEnabled: { reduceMotionEnabled }
        )
        observer.start()
        observer.stop()

        reduceMotionEnabled = true
        center.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)

        XCTAssertFalse(model.reduceMotion)
    }

    private func statusPresentation(for model: AppModel) -> StatusPresentation {
        StatusPresentation(
            resolved: model.resolved,
            showTimer: model.showTimer,
            reduceMotion: model.reduceMotion
        )
    }
}

private struct AppModelAllowanceAdapter: AllowanceProviding {
    let provider: AgentProvider
    func fetch() async throws -> ProviderAllowance {
        .init(
            provider: provider,
            currentWindowLabel: "5h",
            currentPercentUsed: 25,
            currentResetAt: nil,
            weeklyPercentUsed: 10,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
    }
}

private final class AppModelAllowanceCache: AllowanceCaching, @unchecked Sendable {
    private var values: [AgentProvider: ProviderAllowance] = [:]
    func save(_ allowance: ProviderAllowance) throws { values[allowance.provider] = allowance }
    func load(_ provider: AgentProvider) throws -> ProviderAllowance? { values[provider] }
    func remove(_ provider: AgentProvider) throws { values.removeValue(forKey: provider) }
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

private final class FailingAfterFirstLoadStore: SessionStateStoring {
    enum Failure: Error {
        case loadFailed
    }

    private let events: [NormalizedEvent]
    private var loadCount = 0

    init(events: [NormalizedEvent]) {
        self.events = events
    }

    func write(_ event: NormalizedEvent) throws {}

    func loadAll() throws -> [NormalizedEvent] {
        loadCount += 1
        if loadCount > 1 {
            throw Failure.loadFailed
        }
        return events
    }

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
