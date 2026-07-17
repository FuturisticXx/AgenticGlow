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
    private let now: () -> Date
    private var timer: Timer?
    private var resolutionMemory = ResolutionMemory()
    private var allowanceStates: [AgentProvider: AllowanceAvailability] = [:]
    private var serviceStatuses: [AgentProvider: ProviderServiceStatus] = [:]

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
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.processMonitor = processMonitor
        self.activator = activator
        self.allowanceCoordinator = allowanceCoordinator
        self.notifier = notifier
        self.statusMonitor = statusMonitor
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
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let previousPhases = Dictionary(uniqueKeysWithValues: resolved.sessions.map { ($0.id, $0.phase) })
        let events: [NormalizedEvent]
        do {
            events = try store.loadAll()
        } catch {
            storeErrorDescription = String(describing: error)
            resolutionMemory = ResolutionMemory()
            resolved = SessionResolver.resolve(
                events: [],
                now: now(),
                memory: &resolutionMemory,
                isProcessAlive: { _, _ in false }
            )
            return
        }

        let currentTime = now()
        var removalError: Error?
        for event in events where currentTime.timeIntervalSince(event.updatedAt) > SessionResolver.fileRetention {
            do {
                try store.remove(SessionKey(event))
            } catch {
                removalError = error
            }
        }

        storeErrorDescription = removalError.map { String(describing: $0) }
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
    }

    /// A session's turn just ended, cleanly or not, so usage may have
    /// changed. `.failed` reaches this the same as `.completed`: both
    /// consumed quota before their process stopped.
    static func endedThisRefresh(_ session: SessionSnapshot, previousPhases: [String: SessionPhase]) -> Bool {
        [.completed, .failed].contains(session.phase) && previousPhases[session.id] != session.phase
    }

    func activate(_ session: SessionSnapshot) {
        activator.activate(bundleIdentifier: session.sourceBundleID)
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
    }
}
