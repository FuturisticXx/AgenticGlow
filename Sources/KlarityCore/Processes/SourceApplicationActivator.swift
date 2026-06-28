import AppKit
import Darwin
import Foundation

public protocol ProcessMonitoring: Sendable {
    func isAlive(processID: Int32, startedAt: Date?) -> Bool
}

public struct DarwinProcessMonitor: ProcessMonitoring {
    private let inspector: any ProcessInspecting

    public init(inspector: any ProcessInspecting = DarwinProcessInspector()) {
        self.inspector = inspector
    }

    public func isAlive(processID: Int32, startedAt: Date?) -> Bool {
        guard kill(processID, 0) == 0,
              let current = inspector.process(processID) else {
            return false
        }
        guard let expected = startedAt, let actual = current.startedAt else {
            return true
        }
        return abs(actual.timeIntervalSince(expected)) < 1
    }
}

public protocol ApplicationActivating: Sendable {
    @discardableResult
    func activate(bundleIdentifier: String?) -> Bool
}

public struct SourceApplicationActivator: ApplicationActivating {
    public init() {}

    @discardableResult
    public func activate(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier,
              let application = NSRunningApplication.runningApplications(
                  withBundleIdentifier: bundleIdentifier
              ).first else {
            return false
        }
        return application.activate(options: [.activateAllWindows])
    }
}
