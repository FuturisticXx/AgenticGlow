import Foundation

public enum HookEventKind: String, CaseIterable, Sendable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case notification = "Notification"
    case permissionRequest = "PermissionRequest"
    case stop = "Stop"

    /// Cursor's native `hooks.json` key for this event. Cursor uses camelCase
    /// names and maps Claude's `UserPromptSubmit` to `beforeSubmitPrompt`.
    public var cursorHookName: String {
        switch self {
        case .sessionStart: "sessionStart"
        case .sessionEnd: "sessionEnd"
        case .userPromptSubmit: "beforeSubmitPrompt"
        case .preToolUse: "preToolUse"
        case .postToolUse: "postToolUse"
        case .postToolUseFailure: "postToolUseFailure"
        case .notification: "notification"
        case .permissionRequest: "permissionRequest"
        case .stop: "stop"
        }
    }

    public static let cursorEvents: [HookEventKind] = [
        .sessionStart, .sessionEnd, .userPromptSubmit, .preToolUse,
        .postToolUse, .postToolUseFailure, .stop
    ]
}
