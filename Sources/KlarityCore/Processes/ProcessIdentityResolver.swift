import Foundation

public struct ProcessIdentityResolver: Sendable {
    public static let live = ProcessIdentityResolver(inspector: DarwinProcessInspector())
    private let inspector: any ProcessInspecting

    public init(inspector: any ProcessInspecting) {
        self.inspector = inspector
    }

    public func resolve(
        provider: AgentProvider,
        environment: [String: String]
    ) -> ProcessIdentity? {
        let expectedNames = provider == .codex
            ? ["codex", "Codex"]
            : ["claude", "Claude"]
        let isCLI = environment["TERM_PROGRAM"] != nil
        var agentProcess: InspectedProcess?
        var sourceBundle = isCLI ? environment["__CFBundleIdentifier"] : nil
        var pid = inspector.currentParentPID

        for _ in 0..<12 {
            guard pid > 1, let row = inspector.process(pid) else { break }
            if agentProcess == nil,
               expectedNames.contains(where: { row.name.localizedCaseInsensitiveContains($0) }) {
                agentProcess = row
                if !isCLI {
                    sourceBundle = row.bundleID
                }
            }
            if isCLI, sourceBundle == nil, let bundleID = row.bundleID {
                sourceBundle = bundleID
            }
            if let agentProcess, sourceBundle != nil {
                return ProcessIdentity(
                    processID: agentProcess.pid,
                    startedAt: agentProcess.startedAt,
                    bundleIdentifier: sourceBundle
                )
            }
            pid = row.parentPID
        }

        guard let agentProcess else { return nil }
        return ProcessIdentity(
            processID: agentProcess.pid,
            startedAt: agentProcess.startedAt,
            bundleIdentifier: sourceBundle
        )
    }
}
