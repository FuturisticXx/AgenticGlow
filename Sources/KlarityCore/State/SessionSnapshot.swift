import Foundation

public struct SessionSnapshot: Identifiable, Equatable, Sendable {
    public var id: String { "\(provider.rawValue):\(sessionID)" }
    public let provider: AgentProvider
    public let surface: SourceSurface
    public let sessionID: String
    public let phase: SessionPhase
    public let label: String
    public let projectName: String
    public let sourceBundleID: String?
    public let elapsedSeconds: Int?
    public let updatedAt: Date
}

public struct ResolvedSessions: Equatable, Sendable {
    public let sessions: [SessionSnapshot]
    public let dominantPhase: SessionPhase
    public let activeCount: Int
    public let permissionCount: Int
}

public struct ResolutionMemory: Sendable {
    public var disconnectedAt: [SessionKey: Date] = [:]

    public init() {}
}
