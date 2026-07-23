import Foundation

/// The widget-safe view of AgenticGlow's state. Contains only fields already
/// covered by the existing privacy contract (docs/privacy.md): no prompts,
/// no raw provider responses, no credentials. Written by the main app to the
/// App Group shared container and read by the widget extension.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let sessions: [WidgetSessionSummary]
    public let allowances: [WidgetAllowanceSummary]
    public let providers: [WidgetProviderSummary]
    public let attentionCount: Int
    public let activeCount: Int

    public init(
        schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
        generatedAt: Date,
        sessions: [WidgetSessionSummary],
        allowances: [WidgetAllowanceSummary],
        providers: [WidgetProviderSummary],
        attentionCount: Int,
        activeCount: Int
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.sessions = sessions
        self.allowances = allowances
        self.providers = providers
        self.attentionCount = attentionCount
        self.activeCount = activeCount
    }

    public static let empty = WidgetSnapshot(
        generatedAt: .distantPast,
        sessions: [],
        allowances: [],
        providers: [],
        attentionCount: 0,
        activeCount: 0
    )
}

public struct WidgetSessionSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(provider.rawValue):\(sessionID)" }
    public let provider: AgentProvider
    public let sessionID: String
    public let projectName: String
    public let phase: SessionPhase
    public let toolCategory: ToolCategory?
    public let elapsedSeconds: Int?
    public let updatedAt: Date
    public let needsAttention: Bool

    public init(
        provider: AgentProvider,
        sessionID: String,
        projectName: String,
        phase: SessionPhase,
        toolCategory: ToolCategory?,
        elapsedSeconds: Int?,
        updatedAt: Date,
        needsAttention: Bool
    ) {
        self.provider = provider
        self.sessionID = sessionID
        self.projectName = projectName
        self.phase = phase
        self.toolCategory = toolCategory
        self.elapsedSeconds = elapsedSeconds
        self.updatedAt = updatedAt
        self.needsAttention = needsAttention
    }
}

public struct WidgetAllowanceSummary: Codable, Equatable, Sendable {
    public let provider: AgentProvider
    public let currentWindowLabel: String
    public let currentPercentLeft: Double?
    public let currentResetAt: Date?
    public let weeklyPercentLeft: Double?
    public let weeklyResetAt: Date?
    public let fetchedAt: Date

    public init(
        provider: AgentProvider,
        currentWindowLabel: String,
        currentPercentLeft: Double?,
        currentResetAt: Date?,
        weeklyPercentLeft: Double?,
        weeklyResetAt: Date?,
        fetchedAt: Date
    ) {
        self.provider = provider
        self.currentWindowLabel = currentWindowLabel
        self.currentPercentLeft = currentPercentLeft
        self.currentResetAt = currentResetAt
        self.weeklyPercentLeft = weeklyPercentLeft
        self.weeklyResetAt = weeklyResetAt
        self.fetchedAt = fetchedAt
    }

    /// Individual allowance windows to display, derived from the stored
    /// current/weekly fields. Always includes the current window; the
    /// weekly window only appears when the provider actually reports one
    /// (Codex, for example, currently reports only a single window labeled
    /// "Weekly" with no separate secondary value). Not stored on disk: a
    /// display-layer projection over already-serialized fields, so it
    /// doesn't need Codable or a schema version bump.
    public var windows: [WidgetAllowanceWindow] {
        var result = [
            WidgetAllowanceWindow(
                provider: provider,
                kind: .current,
                label: currentWindowLabel,
                percentLeft: currentPercentLeft,
                resetAt: currentResetAt
            )
        ]
        if let weeklyPercentLeft {
            result.append(
                WidgetAllowanceWindow(
                    provider: provider,
                    kind: .weekly,
                    label: "Weekly",
                    percentLeft: weeklyPercentLeft,
                    resetAt: weeklyResetAt
                )
            )
        }
        return result
    }
}

/// A single allowance window ready for display: one bar, one percentage,
/// one label. Not Codable: it's a computed presentation over
/// `WidgetAllowanceSummary`'s stored fields, not part of the shared
/// snapshot's serialized schema.
public struct WidgetAllowanceWindow: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case current
        case weekly
    }

    public let provider: AgentProvider
    public let kind: Kind
    public let label: String
    public let percentLeft: Double?
    public let resetAt: Date?

    public init(
        provider: AgentProvider,
        kind: Kind,
        label: String,
        percentLeft: Double?,
        resetAt: Date?
    ) {
        self.provider = provider
        self.kind = kind
        self.label = label
        self.percentLeft = percentLeft
        self.resetAt = resetAt
    }

    public var id: String {
        "\(provider.rawValue):\(kind.rawValue)"
    }

    public var normalizedProgress: Double? {
        percentLeft.map { min(max($0 / 100, 0), 1) }
    }
}

public struct WidgetProviderSummary: Codable, Equatable, Sendable {
    public let provider: AgentProvider
    public let installed: Bool

    public init(provider: AgentProvider, installed: Bool) {
        self.provider = provider
        self.installed = installed
    }
}
