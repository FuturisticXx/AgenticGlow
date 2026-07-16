import Foundation

public enum AgentProvider: String, Codable, CaseIterable, Sendable {
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        }
    }
}

public enum SourceSurface: String, Codable, Sendable {
    case cli
    case desktop
    case unknown
}

public enum SessionPhase: String, Codable, Sendable {
    case idle
    case thinking
    case usingTool
    case permission
    case completed
    case disconnected
    /// Inferred, not reported: the source process died while the session's
    /// last known phase was `.thinking` or `.usingTool`, i.e. it stopped
    /// mid-task instead of reaching `.completed`. There is no explicit
    /// error/exit-code signal in the hook payload today, so this is a
    /// heuristic, not a confirmed failure reason.
    case failed
}
