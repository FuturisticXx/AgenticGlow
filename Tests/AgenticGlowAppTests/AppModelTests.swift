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
        XCTAssertEqual(activator.projectNames, ["AgenticGlow"])
    }

    func testRemoveSessionHidesItFromResolvedSessions() {
        let store = InMemorySessionStore(events: [
            .testEvent(provider: .codex, phase: .permission, turnStartedAt: nil)
        ])
        let model = AppModel(
            store: store,
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            now: { Date(timeIntervalSince1970: 120) }
        )
        model.refresh()
        XCTAssertEqual(model.resolved.sessions.count, 1)
        let session = model.resolved.sessions[0]

        model.removeSession(session)

        XCTAssertTrue(model.resolved.sessions.isEmpty)
        XCTAssertEqual(store.events.count, 1, "removal must not touch the underlying session file")
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

    func testPermissionTransitionNotifiesExactlyOnce() {
        let event = NormalizedEvent.testEvent(
            provider: .claude,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 90)
        )
        let store = InMemorySessionStore(events: [event])
        let notifier = RecordingNotifier()
        let model = AppModel(
            store: store,
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            notifier: notifier,
            now: { Date(timeIntervalSince1970: 100) }
        )

        model.refresh()
        XCTAssertEqual(notifier.permissionBatches, [])

        store.write(.testEvent(
            provider: .claude,
            phase: .permission,
            turnStartedAt: Date(timeIntervalSince1970: 90)
        ))
        model.refresh()
        model.refresh()

        XCTAssertEqual(notifier.permissionBatches.count, 1)
        XCTAssertEqual(notifier.permissionBatches.first?.map(\.phase), [.permission])
    }

    func testAllowanceUpdatesReachNotifierAndLowAllowanceFlag() async {
        let adapter = MutableAllowanceAdapter(
            provider: .codex,
            allowance: appModelAllowance(currentUsed: 92, weeklyResetAt: nil)
        )
        let notifier = RecordingNotifier()
        let model = AppModel(
            store: InMemorySessionStore(events: []),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            allowanceCoordinator: AllowanceRefreshCoordinator(
                adapters: [adapter],
                cache: AppModelAllowanceCache()
            ),
            notifier: notifier,
            now: { Date(timeIntervalSince1970: 1_783_099_000) }
        )

        await model.setUsageEnabled(true, provider: .codex)

        XCTAssertEqual(notifier.allowanceUpdates.map(\.0), [.codex])
        XCTAssertTrue(model.hasLowAllowance)
    }

    func testWeeklyRolloverIncrementsResetCount() async {
        let now = Date(timeIntervalSince1970: 1_783_099_000)
        let adapter = MutableAllowanceAdapter(
            provider: .codex,
            allowance: appModelAllowance(
                currentUsed: 20,
                weeklyResetAt: now.addingTimeInterval(-60)
            )
        )
        let model = AppModel(
            store: InMemorySessionStore(events: []),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            allowanceCoordinator: AllowanceRefreshCoordinator(
                adapters: [adapter],
                cache: AppModelAllowanceCache()
            ),
            now: { now }
        )

        await model.setUsageEnabled(true, provider: .codex)
        XCTAssertEqual(model.weeklyResetCount, 0)

        adapter.update(appModelAllowance(
            currentUsed: 1,
            weeklyResetAt: now.addingTimeInterval(6 * 86_400)
        ))
        await model.refreshUsage(.manual)

        XCTAssertEqual(model.weeklyResetCount, 1)
    }

    func testEndedThisRefreshFiresOnTransitionIntoCompleted() {
        let session = self.session(sessionID: "s", phase: .completed)
        XCTAssertTrue(AppModel.endedThisRefresh(session, previousPhases: [session.id: .thinking]))
    }

    func testEndedThisRefreshFiresOnTransitionIntoFailed() {
        let session = self.session(sessionID: "s", phase: .failed)
        XCTAssertTrue(AppModel.endedThisRefresh(session, previousPhases: [session.id: .usingTool]))
    }

    func testEndedThisRefreshIgnoresSteadyCompletedOrFailed() {
        let completed = session(sessionID: "c", phase: .completed)
        XCTAssertFalse(AppModel.endedThisRefresh(completed, previousPhases: [completed.id: .completed]))

        let failed = session(sessionID: "f", phase: .failed)
        XCTAssertFalse(AppModel.endedThisRefresh(failed, previousPhases: [failed.id: .failed]))
    }

    func testEndedThisRefreshIgnoresOtherPhases() {
        let thinking = session(sessionID: "t", phase: .thinking)
        XCTAssertFalse(AppModel.endedThisRefresh(thinking, previousPhases: [:]))
    }

    private func session(sessionID: String, phase: SessionPhase) -> SessionSnapshot {
        SessionSnapshot(
            provider: .codex,
            surface: .cli,
            sessionID: sessionID,
            phase: phase,
            label: phase.rawValue,
            projectName: "AgenticGlow",
            sourceBundleID: "com.apple.Terminal",
            elapsedSeconds: nil,
            updatedAt: Date()
        )
    }

    func testServiceStatusFlowsFromMonitor() async {
        let monitor = ProviderStatusMonitor(
            requester: IncidentStatusRequester(),
            ttl: 600,
            now: { Date(timeIntervalSince1970: 1_783_099_000) }
        )
        let model = AppModel(
            store: InMemorySessionStore(events: []),
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            statusMonitor: monitor
        )

        XCTAssertNil(model.serviceStatus(for: .claude))

        await model.setServiceStatusEnabled(true)

        XCTAssertEqual(
            model.serviceStatus(for: .claude),
            .incident("Partial System Degradation")
        )

        await model.setServiceStatusEnabled(false)

        XCTAssertNil(model.serviceStatus(for: .claude))
    }

    private func appModelAllowance(
        currentUsed: Double?,
        weeklyResetAt: Date?
    ) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentUsed,
            currentResetAt: nil,
            weeklyPercentUsed: 20,
            weeklyResetAt: weeklyResetAt,
            fetchedAt: Date(timeIntervalSince1970: 1_783_099_000)
        )
    }

    private func statusPresentation(for model: AppModel) -> StatusPresentation {
        StatusPresentation(
            resolved: model.resolved,
            showTimer: model.showTimer,
            reduceMotion: model.reduceMotion
        )
    }
}

@MainActor
private final class RecordingNotifier: AgentNotifying {
    private(set) var permissionBatches: [[SessionSnapshot]] = []
    private(set) var allowanceUpdates: [(AgentProvider, ProviderAllowance)] = []

    func sessionsNeedPermission(_ sessions: [SessionSnapshot]) {
        permissionBatches.append(sessions)
    }

    func allowanceUpdated(provider: AgentProvider, allowance: ProviderAllowance) {
        allowanceUpdates.append((provider, allowance))
    }
}

private final class MutableAllowanceAdapter: AllowanceProviding, @unchecked Sendable {
    let provider: AgentProvider
    private let lock = NSLock()
    private var allowance: ProviderAllowance

    init(provider: AgentProvider, allowance: ProviderAllowance) {
        self.provider = provider
        self.allowance = allowance
    }

    func update(_ allowance: ProviderAllowance) {
        lock.withLock { self.allowance = allowance }
    }

    func fetch() async throws -> ProviderAllowance {
        lock.withLock { allowance }
    }
}

private struct IncidentStatusRequester: ProviderStatusRequesting {
    func fetchStatus(for provider: AgentProvider) async throws -> Data {
        Data(#"{"status":{"indicator":"major","description":"Partial System Degradation"}}"#.utf8)
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
    private(set) var projectNames: [String?] = []

    func activate(bundleIdentifier: String?, projectName: String?) -> Bool {
        bundleIdentifiers.append(bundleIdentifier)
        projectNames.append(projectName)
        return true
    }
}
