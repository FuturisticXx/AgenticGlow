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
    public let toolCategory: ToolCategory?

    public init(
        provider: AgentProvider,
        surface: SourceSurface,
        sessionID: String,
        phase: SessionPhase,
        label: String,
        projectName: String,
        sourceBundleID: String?,
        elapsedSeconds: Int?,
        updatedAt: Date,
        toolCategory: ToolCategory? = nil
    ) {
        self.provider = provider
        self.surface = surface
        self.sessionID = sessionID
        self.phase = phase
        self.label = label
        self.projectName = projectName
        self.sourceBundleID = sourceBundleID
        self.elapsedSeconds = elapsedSeconds
        self.updatedAt = updatedAt
        self.toolCategory = toolCategory
    }
}

public struct ResolvedSessions: Equatable, Sendable {
    public let sessions: [SessionSnapshot]
    public let dominantPhase: SessionPhase
    public let activeCount: Int
    public let permissionCount: Int
    /// Providers with at least one session actively working (thinking or
    /// using a tool). Permission and idle do not count as working.
    public let activeProviders: Set<AgentProvider>
}

struct DisconnectionRecord: Sendable {
    let eventUpdatedAt: Date
    let detectedAt: Date
}

struct HiddenRecord: Sendable {
    let eventUpdatedAt: Date
}

public struct ResolutionMemory: Sendable {
    var disconnectedRecords: [SessionKey: DisconnectionRecord] = [:]
    var hiddenRecords: [SessionKey: HiddenRecord] = [:]

    public init() {}

    /// Records a client-side hide for `key`. The session stays excluded from
    /// resolved sessions until a newer event (a different `updatedAt`)
    /// arrives for the same key. Never touches the underlying session file.
    public mutating func hide(_ key: SessionKey, eventUpdatedAt: Date) {
        hiddenRecords[key] = HiddenRecord(eventUpdatedAt: eventUpdatedAt)
    }
}
