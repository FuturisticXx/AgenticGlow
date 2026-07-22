import AppKit
import Foundation
import AgenticGlowCore
import Observation

struct SessionDataErrorPresentation: Equatable {
    let title: String
    let message: String
}

@MainActor
@Observable
final class AppModel {
    private let store: SessionStateStoring
    private let processMonitor: ProcessMonitoring
    private let activator: ApplicationActivating
    private let allowanceCoordinator: AllowanceRefreshCoordinator?
    private let notifier: (any AgentNotifying)?
    private let statusMonitor: ProviderStatusMonitor?
    private let codexSessionDiscoverer: (any CodexSessionDiscovering)?
    private let widgetSnapshotWriter: (any WidgetSnapshotWriting)?
    private let widgetTimelineReloader: (any WidgetTimelineReloading)?
    private let installedProviders: (() -> [AgentProvider: Bool])?
    private let now: () -> Date
    private var timer: Timer?
    private var codexDiscoveryTask: Task<Void, Never>?
    private var resolutionMemory = ResolutionMemory()
    private var discoveredCodexEvents: [NormalizedEvent] = []
    private var allowanceStates: [AgentProvider: AllowanceAvailability] = [:]
    private var serviceStatuses: [AgentProvider: ProviderServiceStatus] = [:]
    private var lastWidgetSnapshot: WidgetSnapshot?
    private var cachedInstalledProviders: [AgentProvider: Bool] = [:]
    private var installedProvidersCheckedAt: Date?

    private(set) var resolved: ResolvedSessions
    private(set) var storeErrorDescription: String?
    private(set) var weeklyResetCount = 0
    var showTimer = false
    var reduceMotion = false
    var sessionDataErrorPresentation: SessionDataErrorPresentation? {
        guard storeErrorDescription != nil else { return nil }
        return SessionDataErrorPresentation(
            title: "Session data unavailable",
            message: "Check Integrations and try again."
        )
    }

    init(
        store: SessionStateStoring,
        processMonitor: ProcessMonitoring,
        activator: ApplicationActivating,
        allowanceCoordinator: AllowanceRefreshCoordinator? = nil,
        notifier: (any AgentNotifying)? = nil,
        statusMonitor: ProviderStatusMonitor? = nil,
        codexSessionDiscoverer: (any CodexSessionDiscovering)? = nil,
        widgetSnapshotWriter: (any WidgetSnapshotWriting)? = nil,
        widgetTimelineReloader: (any WidgetTimelineReloading)? = nil,
        installedProviders: (() -> [AgentProvider: Bool])? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.processMonitor = processMonitor
        self.activator = activator
        self.allowanceCoordinator = allowanceCoordinator
        self.notifier = notifier
        self.statusMonitor = statusMonitor
        self.codexSessionDiscoverer = codexSessionDiscoverer
        self.widgetSnapshotWriter = widgetSnapshotWriter
        self.widgetTimelineReloader = widgetTimelineReloader
        self.installedProviders = installedProviders
        self.now = now
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        showTimer = UserDefaults.standard.bool(forKey: "showTimer")
        var initialMemory = ResolutionMemory()
        resolved = SessionResolver.resolve(
            events: [],
            now: now(),
            memory: &initialMemory,
            isProcessAlive: { _, _ in false }
        )
    }

    func start() {
        stop()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        if codexSessionDiscoverer != nil {
            codexDiscoveryTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refreshCodexDiscovery()
                    try? await Task.sleep(for: CodexSessionDiscoveryAdapter.refreshInterval)
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        codexDiscoveryTask?.cancel()
        codexDiscoveryTask = nil
    }

    func refresh() {
        let previousPhases = Dictionary(uniqueKeysWithValues: resolved.sessions.map { ($0.id, $0.phase) })
        let storedEvents: [NormalizedEvent]
        do {
            storedEvents = try store.loadAll()
        } catch {
            storeErrorDescription = String(describing: error)
            resolutionMemory = ResolutionMemory()
            resolved = SessionResolver.resolve(
                events: [],
                now: now(),
                memory: &resolutionMemory,
                isProcessAlive: { _, _ in false }
            )
            syncWidgetSnapshot()
            return
        }

        let currentTime = now()
        var removalError: Error?
        for event in storedEvents where currentTime.timeIntervalSince(event.updatedAt) > SessionResolver.fileRetention {
            do {
                try store.remove(SessionKey(event))
            } catch {
                removalError = error
            }
        }

        storeErrorDescription = removalError.map { String(describing: $0) }
        let events = SessionEventMerger.merge(
            stored: storedEvents,
            discoveredCodex: discoveredCodexEvents
        )
        resolved = SessionResolver.resolve(
            events: events,
            now: currentTime,
            memory: &resolutionMemory,
            isProcessAlive: { [processMonitor] processID, startedAt in
                processMonitor.isAlive(processID: processID, startedAt: startedAt)
            }
        )
        if let notifier {
            let newlyWaiting = NotificationPolicy.newlyAwaitingPermission(
                previousPhases: previousPhases,
                sessions: resolved.sessions
            )
            if !newlyWaiting.isEmpty {
                notifier.sessionsNeedPermission(newlyWaiting)
            }
        }
        if resolved.sessions.contains(where: { Self.endedThisRefresh($0, previousPhases: previousPhases) }) {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(AllowanceRefreshPolicy.turnCompletionDebounce))
                await self?.refreshUsage(.turnCompleted)
            }
        } else if resolved.dominantPhase.isActive {
            Task { [weak self] in await self?.refreshUsage(.working) }
        } else if resolved.dominantPhase == .idle {
            Task { [weak self] in await self?.refreshUsage(.idle) }
        }
        syncWidgetSnapshot()
    }

    func refreshCodexDiscovery() async {
        guard let codexSessionDiscoverer else { return }
        do {
            discoveredCodexEvents = try await codexSessionDiscoverer.discover()
            refresh()
        } catch {
            // Preserve the last successful result. SessionResolver will age it
            // out naturally if Codex remains unavailable.
        }
    }

    /// A session's turn just ended, cleanly or not, so usage may have
    /// changed. `.failed` reaches this the same as `.completed`: both
    /// consumed quota before their process stopped.
    static func endedThisRefresh(_ session: SessionSnapshot, previousPhases: [String: SessionPhase]) -> Bool {
        [.completed, .failed].contains(session.phase) && previousPhases[session.id] != session.phase
    }

    func activate(_ session: SessionSnapshot) {
        activator.activate(bundleIdentifier: session.sourceBundleID, projectName: session.projectName)
    }

    func removeSession(_ session: SessionSnapshot) {
        resolutionMemory.hide(
            SessionKey(provider: session.provider, sessionID: session.sessionID),
            eventUpdatedAt: session.updatedAt
        )
        refresh()
    }

    func allowanceState(for provider: AgentProvider) -> AllowanceAvailability {
        allowanceStates[provider] ?? .off
    }

    var hasLowAllowance: Bool {
        allowanceStates.values.contains { state in
            guard case let .available(allowance, _) = state else { return false }
            return !AllowanceWarning.lowWindows(in: allowance).isEmpty
        }
    }

    func serviceStatus(for provider: AgentProvider) -> ProviderServiceStatus? {
        serviceStatuses[provider]
    }

    func setServiceStatusEnabled(_ enabled: Bool) async {
        guard let statusMonitor else { return }
        await statusMonitor.setEnabled(enabled)
        if enabled {
            await refreshServiceStatus()
        } else {
            serviceStatuses = [:]
        }
    }

    /// Drives the celebration deterministically for visual verification.
    /// Only reachable via the --ui-test-celebrate launch argument.
    func triggerWeeklyResetForUITest() {
        weeklyResetCount += 1
    }

    func refreshServiceStatus() async {
        guard let statusMonitor else { return }
        await statusMonitor.refreshIfStale()
        var statuses: [AgentProvider: ProviderServiceStatus] = [:]
        for provider in AgentProvider.allCases {
            statuses[provider] = await statusMonitor.status(for: provider)
        }
        serviceStatuses = statuses
    }

    func setUsageEnabled(_ enabled: Bool, provider: AgentProvider) async {
        guard let allowanceCoordinator else { return }
        await allowanceCoordinator.setEnabled(enabled, provider: provider)
        await syncAllowanceStates()
    }

    func refreshUsage(_ reason: AllowanceRefreshReason = .manual) async {
        guard let allowanceCoordinator else { return }
        await allowanceCoordinator.refresh(reason)
        await syncAllowanceStates()
    }

    func setUsageSuspended(_ suspended: Bool) async {
        guard let allowanceCoordinator else { return }
        await allowanceCoordinator.setSuspended(suspended)
        if !suspended {
            await refreshUsage(.popoverOpened)
        }
    }

    private func syncAllowanceStates() async {
        guard let allowanceCoordinator else { return }
        for provider in AgentProvider.allCases {
            let previous = allowanceStates[provider]
            let state = await allowanceCoordinator.state(for: provider)
            allowanceStates[provider] = state
            guard case let .available(allowance, _) = state else { continue }
            notifier?.allowanceUpdated(provider: provider, allowance: allowance)
            var previousAllowance: ProviderAllowance?
            if case let .available(value, _)? = previous {
                previousAllowance = value
            }
            if WeeklyResetDetector.didReset(
                previous: previousAllowance,
                current: allowance,
                now: now()
            ) {
                weeklyResetCount += 1
            }
        }
        syncWidgetSnapshot()
    }

    /// Builds the widget-safe snapshot from current state and writes it to
    /// the shared App Group container, reloading the widget's timeline
    /// only when something worth showing actually changed. No-ops entirely
    /// when widget integration is not injected, such as in fixtures and
    /// tests that do not exercise the widget path.
    private func syncWidgetSnapshot() {
        guard let widgetSnapshotWriter else { return }
        var allowances: [AgentProvider: ProviderAllowance] = [:]
        for provider in AgentProvider.allCases {
            guard case let .available(allowance, _) = allowanceState(for: provider) else { continue }
            allowances[provider] = allowance
        }
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved,
            allowances: allowances,
            installedProviders: refreshedInstalledProviders(),
            now: now()
        )
        if let last = lastWidgetSnapshot, !WidgetSnapshotBuilder.isMeaningfullyDifferent(snapshot, from: last) {
            return
        }
        do {
            try widgetSnapshotWriter.write(snapshot)
        } catch {
            return
        }
        lastWidgetSnapshot = snapshot
        widgetTimelineReloader?.reloadAll()
    }

    /// installedProviders does file I/O (reads settings.json/hooks.json).
    /// refresh() runs every 2s, so this is cached and only re-checked on
    /// the same idle cadence as allowance refreshes; integration status
    /// changes only when the user installs/repairs a provider by hand.
    private func refreshedInstalledProviders() -> [AgentProvider: Bool] {
        guard let installedProviders else { return [:] }
        let currentTime = now()
        if let checkedAt = installedProvidersCheckedAt,
           currentTime.timeIntervalSince(checkedAt) < AllowanceRefreshPolicy.idleInterval {
            return cachedInstalledProviders
        }
        installedProvidersCheckedAt = currentTime
        cachedInstalledProviders = installedProviders()
        return cachedInstalledProviders
    }
}
