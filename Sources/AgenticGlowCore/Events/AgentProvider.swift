import Foundation

public enum AgentProvider: String, Codable, CaseIterable, Sendable {
    case codex
    case claude
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
}
