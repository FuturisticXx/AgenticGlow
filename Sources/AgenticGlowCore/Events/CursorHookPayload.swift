import Foundation

/// Maps Cursor's documented hook stdin JSON onto the fields
/// `HookNormalizer` already understands.
///
/// Cursor's official common schema uses `conversation_id` and
/// `workspace_roots` instead of Claude/Codex `session_id` and `cwd`.
/// This adapter copies only those identity fields. It does not persist
/// `prompt`, `command`, `tool_input`, `user_email`, or `transcript_path`.
public enum CursorHookPayload {
    public static func normalized(_ payload: [String: Any]) -> [String: Any] {
        var result = payload

        if sessionIdentifier(in: result) == nil,
           let conversationID = string(payload["conversation_id"]) {
            result["session_id"] = conversationID
        }

        if workingDirectory(in: result) == nil,
           let cwd = inferredWorkingDirectory(from: payload) {
            result["cwd"] = cwd
        }

        if result["turn_id"] == nil,
           let generationID = string(payload["generation_id"]) {
            result["turn_id"] = generationID
        }

        if string(result["tool_name"]) == nil,
           let toolName = inferredToolName(from: payload) {
            result["tool_name"] = toolName
        }

        for key in [
            "prompt", "attachments", "command", "tool_input", "tool_output",
            "user_email", "transcript_path", "error_message", "agent_message",
            "edits", "summary", "task"
        ] {
            result.removeValue(forKey: key)
        }

        return result
    }

    private static func sessionIdentifier(in payload: [String: Any]) -> String? {
        string(payload["session_id"])
    }

    private static func workingDirectory(in payload: [String: Any]) -> String? {
        guard let cwd = string(payload["cwd"]), cwd.hasPrefix("/") else { return nil }
        return cwd
    }

    private static func inferredWorkingDirectory(from payload: [String: Any]) -> String? {
        if let cwd = string(payload["cwd"]), cwd.hasPrefix("/") {
            return cwd
        }
        if let roots = payload["workspace_roots"] as? [String],
           let first = roots.first(where: { $0.hasPrefix("/") }) {
            return first
        }
        if let toolInput = payload["tool_input"] as? [String: Any],
           let workingDirectory = string(toolInput["working_directory"]),
           workingDirectory.hasPrefix("/") {
            return workingDirectory
        }
        return nil
    }

    private static func inferredToolName(from payload: [String: Any]) -> String? {
        if let toolName = string(payload["tool_name"]) {
            return toolName
        }
        if payload["command"] != nil {
            return "Shell"
        }
        if payload["file_path"] != nil {
            return payload["edits"] == nil ? "Read" : "Write"
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }
}
