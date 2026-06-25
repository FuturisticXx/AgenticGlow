import Foundation

public enum ToolCategory: String, Codable, Sendable {
    case read
    case edit
    case search
    case browse
    case command
    case delegate
    case other

    public static func classify(_ toolName: String) -> Self {
        switch toolName {
        case "Read":
            .read
        case "Edit", "Write", "MultiEdit", "apply_patch":
            .edit
        case "Grep", "Glob", "find", "rg":
            .search
        case "WebFetch", "WebSearch", "web_search":
            .browse
        case "Bash", "exec_command", "write_stdin":
            .command
        case "Task", "spawn_agent":
            .delegate
        default:
            .other
        }
    }

    public var label: String {
        switch self {
        case .read:
            "Reading"
        case .edit:
            "Editing"
        case .search:
            "Searching"
        case .browse:
            "Browsing"
        case .command:
            "Running command"
        case .delegate:
            "Delegating"
        case .other:
            "Using tool"
        }
    }
}
