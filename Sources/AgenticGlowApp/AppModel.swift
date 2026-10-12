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
    private let resetAlerts: (any UsageResetAlerting)?
    private let statusMonitor: ProviderStatusMonitor?
    private let codexSessionDiscoverer: (any CodexSessionDiscovering)?
    private let widgetSnapshotWriter: (any WidgetSnapshotWriting)?
    private let widgetTimelineReloader: (any WidgetTimelineReloading)?
    /// Sees every snapshot the app builds, changed or not, and decides
    /// for itself what to publish for the iPhone widget.
    private let stateSyncPublisher: (any WidgetSnapshotSyncing)?
    private let installedProviders: (() -> [AgentProvider: Bool])?
    private let now: () -> Date
    private var timer: Timer?
    private var codexDiscoveryTask: Task<Void, Never>?
    private var resolutionMemory = ResolutionMemory()
    private var discoveredCodexEvents: [NormalizedEvent] = []
    private var allowanceStates: [AgentProvider: AllowanceAvailability] = [:]
    private var serviceStatuses: [AgentProvider: ProviderServiceStatus] = [:]
    private var lastWidgetSnapshot: WidgetSnapshot?
    /// Snapshots published this launch. Advances only when a meaningfully
    /// different snapshot is written, so it counts real data changes rather
    /// than attempts or re-reads of unchanged values. In memory only: nothing new is stored on disk for it, and
    /// starting over at zero after a relaunch simply shows the first
    /// session again.
    private var widgetSnapshotRevision = 0
    private var cachedInstalledProviders: [AgentProvider: Bool] = [:]
    private var installedProvidersCheckedAt: Date?
    private var lastUsageResets: [AgentProvider: UsageResetDelivery] = [:]

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
        resetAlerts: (any UsageResetAlerting)? = nil,
        statusMonitor: ProviderStatusMonitor? = nil,
        codexSessionDiscoverer: (any CodexSessionDiscovering)? = nil,
        widgetSnapshotWriter: (any WidgetSnapshotWriting)? = nil,
        widgetTimelineReloader: (any WidgetTimelineReloading)? = nil,
        stateSyncPublisher: (any WidgetSnapshotSyncing)? = nil,
        installedProviders: (() -> [AgentProvider: Bool])? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.processMonitor = processMonitor
        self.activator = activator
        self.allowanceCoordinator = allowanceCoordinator
        self.notifier = notifier
        self.resetAlerts = resetAlerts
        self.statusMonitor = statusMonitor
        self.codexSessionDiscoverer = codexSessionDiscoverer
        self.widgetSnapshotWriter = widgetSnapshotWriter
        self.widgetTimelineReloader = widgetTimelineReloader
        self.stateSyncPublisher = stateSyncPublisher
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
            // Usage does not depend on the session store, so a failed read
            // must not stop the usage timer with it.
            Task { [weak self] in await self?.refreshUsage(.idle) }
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
            let newlyFailed = NotificationPolicy.newlyFailed(
                previousPhases: previousPhases,
                sessions: resolved.sessions
            )
            if !newlyFailed.isEmpty {
                notifier.sessionsFailed(newlyFailed)
            }
        }
        switch Self.usageRefreshReason(for: resolved, previousPhases: previousPhases) {
        case .turnCompleted:
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(AllowanceRefreshPolicy.turnCompletionDebounce))
                await self?.refreshUsage(.turnCompleted)
            }
        case let reason:
            Task { [weak self] in await self?.refreshUsage(reason) }
        }
        syncWidgetSnapshot()
    }

    /// Which usage refresh this tick asks for. Every tick asks for one:
    /// the coordinator's own intervals decide whether it actually runs.
    ///
    /// Not keyed on `dominantPhase`. That ranks a permission prompt above
    /// work, and a prompt never ages out, so one session left waiting
    /// stopped every periodic refresh for every provider, and the brief
    /// completed, failed, and disconnected phases did the same.
    static func usageRefreshReason(
        for resolved: ResolvedSessions,
        previousPhases: [String: SessionPhase]
    ) -> AllowanceRefreshReason {
        if resolved.sessions.contains(where: { endedThisRefresh($0, previousPhases: previousPhases) }) {
            return .turnCompleted
        }
        return resolved.sessions.contains(where: { $0.phase.isActive }) ? .working : .idle
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

    /// The most recent confirmed reset for a provider, kept only while it
    /// is still worth showing in the popover. A test alert is not a real
    /// reset, so it never records one.
    func usageReset(for provider: AgentProvider) -> UsageResetDelivery? {
        guard let delivery = lastUsageResets[provider],
              now().timeIntervalSince(delivery.detectedAt) < Self.usageResetNoticeLifetime
        else { return nil }
        return delivery
    }

    func recordUsageReset(_ delivery: UsageResetDelivery) {
        lastUsageResets[delivery.key.provider] = delivery
    }

    /// Long enough to still be there when the user comes back to the Mac,
    /// short enough that yesterday's reset is not presented as news.
    static let usageResetNoticeLifetime: TimeInterval = 6 * 3600

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
            // Every state reaches the reset detector, including failures and
            // off, so it can carry evidence forward or drop it deliberately
            // rather than inferring from an absent update.
            resetAlerts?.allowanceObserved(provider: provider, state: state)
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
        guard widgetSnapshotWriter != nil || stateSyncPublisher != nil else { return }
        var allowances: [AgentProvider: ProviderAllowance] = [:]
        for provider in AgentProvider.allCases {
            guard case let .available(allowance, _) = allowanceState(for: provider) else { continue }
            allowances[provider] = allowance
        }
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved,
            allowances: allowances,
            installedProviders: refreshedInstalledProviders(),
            now: now(),
            revision: widgetSnapshotRevision + 1
        )
        // Offered every tick, whether or not the desktop widget's file
        // changes: the publisher has its own heartbeat, so a quiet Mac
        // keeps telling the phone it is still there.
        stateSyncPublisher?.snapshotDidRefresh(snapshot, now: now())
        guard let widgetSnapshotWriter else { return }
        // The revision is deliberately absent from this comparison: a
        // snapshot must never become worth writing merely because the
        // counter moved, or the widget would reload on every tick.
        let changed = lastWidgetSnapshot.map {
            WidgetSnapshotBuilder.isMeaningfullyDifferent(snapshot, from: $0)
        } ?? true
        // A provider read again with unchanged values is still written, so
        // the widget's next read carries its true observation time instead
        // of the old one. It reloads only when that clears a stale label;
        // otherwise nothing on the canvas changes and WidgetKit's reload
        // budget is kept for real changes.
        let reobserved = lastWidgetSnapshot.map {
            WidgetSnapshotBuilder.allowanceObservationsAdvanced(snapshot, from: $0)
        } ?? false
        guard changed || reobserved else { return }
        let clearsStaleness = lastWidgetSnapshot.map {
            WidgetSnapshotBuilder.clearsStaleAllowance(snapshot, from: $0, now: snapshot.generatedAt)
        } ?? false
        // A re-read keeps the revision: the large widget rotates its session
        // row on revision, and unchanged values are not new data to rotate on.
        let written = changed ? snapshot : snapshot.withRevision(widgetSnapshotRevision)
        do {
            try widgetSnapshotWriter.write(written)
        } catch {
            return
        }
        widgetSnapshotRevision = written.revision
        lastWidgetSnapshot = written
        if changed || clearsStaleness {
            widgetTimelineReloader?.reloadAll()
        }
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
