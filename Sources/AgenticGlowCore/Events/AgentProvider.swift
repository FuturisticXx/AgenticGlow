import Foundation

public enum AgentProvider: String, Codable, CaseIterable, Sendable {
    case codex
    case claude
    case cursor

    public var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .cursor: "Cursor"
        }
    }

    /// Stable Claude, Codex, then Cursor order for menu-bar tints and
    /// summary copy. Distinct from `allCases`, which follows declaration
    /// order and is used for persistence and widget snapshots.
    public static let menuBarTintOrder: [AgentProvider] = [.claude, .codex, .cursor]

    /// Cursor's documented macOS application bundle identifier, verified
    /// against Cursor 3.16.17 at `/Applications/Cursor.app`.
    public static let cursorBundleIdentifier = "com.todesktop.230313mzl4w4u92"
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
    /// Unsuccessful end of a turn. Cursor can report this explicitly via
    /// `stop.status == error`. Codex and Claude still infer it when the
    /// source process dies mid-task before a `.completed` event.
    case failed

    /// True while the session is actively thinking or using a tool. The
    /// single source of truth for "is this session actively working" so
    /// callers don't each hand-roll `[.thinking, .usingTool].contains(...)`.
    public var isActive: Bool {
        self == .thinking || self == .usingTool
    }
}
