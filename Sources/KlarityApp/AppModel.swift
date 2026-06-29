import AppKit
import Foundation
import KlarityCore
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
    private let now: () -> Date
    private var timer: Timer?
    private var resolutionMemory = ResolutionMemory()

    private(set) var resolved: ResolvedSessions
    private(set) var storeErrorDescription: String?
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
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.processMonitor = processMonitor
        self.activator = activator
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
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
    }

    func activate(_ session: SessionSnapshot) {
        activator.activate(bundleIdentifier: session.sourceBundleID)
    }
}
