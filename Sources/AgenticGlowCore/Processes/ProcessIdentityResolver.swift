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
        let expectedName = provider == .codex ? "codex" : "claude"
        // The desktop app's own GUI process is not always named after the agent binary:
        // OpenAI's Codex desktop app ships as "ChatGPT", while the embedded "codex" binary
        // that actually runs the agent is a bare helper executable with no bundle identity
        // of its own (confirmed against a live Codex desktop session, 2026-07-17).
        let desktopAppNames: Set<String> = provider == .codex ? ["codex", "chatgpt"] : ["claude"]
        let isCLI = environment["TERM_PROGRAM"] != nil
        var agentProcess: InspectedProcess?
        var sourceBundle = isCLI ? environment["__CFBundleIdentifier"] : nil
        var pid = inspector.currentParentPID

        for _ in 0..<12 {
            guard pid > 1, let row = inspector.process(pid) else { break }
            let isExactAgentName = row.name.caseInsensitiveCompare(expectedName) == .orderedSame
            if agentProcess == nil, isExactAgentName {
                agentProcess = row
            }
            if isCLI, sourceBundle == nil, let bundleID = row.bundleID {
                sourceBundle = bundleID
            }
            if !isCLI, sourceBundle == nil, desktopAppNames.contains(row.name.lowercased()),
               let bundleID = row.bundleID {
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
