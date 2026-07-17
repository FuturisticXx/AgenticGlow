import AppKit
import Darwin
import Foundation

public protocol ProcessMonitoring: Sendable {
    func isAlive(processID: Int32, startedAt: Date?) -> Bool
}

public struct DarwinProcessMonitor: ProcessMonitoring {
    private static let startTimeTolerance: TimeInterval = 0.000_000_5
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
        return abs(actual.timeIntervalSince(expected)) < Self.startTimeTolerance
    }
}

public protocol ApplicationActivating: Sendable {
    @discardableResult
    func activate(bundleIdentifier: String?, projectName: String?) -> Bool
}

extension ApplicationActivating {
    @discardableResult
    public func activate(bundleIdentifier: String?) -> Bool {
        activate(bundleIdentifier: bundleIdentifier, projectName: nil)
    }
}

public struct SourceApplicationActivator: ApplicationActivating {
    private let activateBundle: @Sendable (String, String?) -> Bool

    public init() {
        activateBundle = { bundleIdentifier, projectName in
            guard let application = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).first else {
                return false
            }
            if bundleIdentifier == CodexWindowScript.codexBundleIdentifier,
               let projectName,
               Self.raiseCodexWindow(projectName: projectName) {
                return true
            }
            return application.activate(options: [.activateAllWindows])
        }
    }

    init(activateBundle: @escaping @Sendable (String, String?) -> Bool) {
        self.activateBundle = activateBundle
    }

    @discardableResult
    public func activate(bundleIdentifier: String?, projectName: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return activateBundle(bundleIdentifier, projectName)
    }

    private static func raiseCodexWindow(projectName: String) -> Bool {
        guard let script = NSAppleScript(source: CodexWindowScript.source(projectName: projectName)) else {
            return false
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}
