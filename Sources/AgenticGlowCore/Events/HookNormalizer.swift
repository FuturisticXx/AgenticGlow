import Foundation
import CryptoKit

public enum HookNormalizationError: Error, Equatable {
    case missingSessionID
    case missingWorkingDirectory
}

public enum HookNormalizer {
    public static func normalize(
        provider: AgentProvider,
        event: HookEventKind,
        payload: [String: Any],
        environment: [String: String],
        processIdentity: ProcessIdentity?,
        previous: NormalizedEvent?,
        now: Date
    ) throws -> NormalizedEvent? {
        guard let sessionID = payload["session_id"] as? String, !sessionID.isEmpty else {
            throw HookNormalizationError.missingSessionID
        }

        guard let cwd = payload["cwd"] as? String, cwd.hasPrefix("/") else {
            throw HookNormalizationError.missingWorkingDirectory
        }

        if event == .notification {
            let notificationType = (payload["notification_type"] as? String)?.lowercased() ?? ""
            let message = (payload["message"] as? String)?.lowercased() ?? ""
            let isPermission: Bool
            if notificationType.isEmpty {
                isPermission = message.contains("permission")
                    || message.contains("approve")
                    || message.contains("allow")
            } else {
                isPermission = notificationType == "permission_prompt"
            }
            guard isPermission else {
                return nil
            }
        }

        let toolName = payload["tool_name"] as? String ?? ""
        let toolCategory = event == .preToolUse ? ToolCategory.classify(toolName) : nil
        let phase: SessionPhase
        let label: String

        switch event {
        case .sessionStart, .sessionEnd:
            phase = .idle
            label = "Idle"
        case .userPromptSubmit, .postToolUse:
            phase = .thinking
            label = "Thinking"
        case .preToolUse:
            phase = .usingTool
            label = toolCategory?.label ?? "Using tool"
        case .notification, .permissionRequest:
            phase = .permission
            label = "Awaiting permission"
        case .stop:
            phase = .completed
            label = "Completed"
        }

        let turnStartedAt: Date?
        switch event {
        case .userPromptSubmit:
            turnStartedAt = now
        case .sessionStart, .sessionEnd, .stop:
            turnStartedAt = nil
        case .preToolUse, .postToolUse, .permissionRequest, .notification:
            turnStartedAt = previous?.turnStartedAt
        }

        let terminalBundleID = environment["__CFBundleIdentifier"]
        let surface: SourceSurface = environment["TERM_PROGRAM"] == nil ? .desktop : .cli
        let normalizedEvent = NormalizedEvent(
            schemaVersion: ProductMetadata.schemaVersion,
            provider: provider,
            surface: surface,
            sessionID: safeIdentifier(prefix: "sid", raw: sessionID),
            turnID: (payload["turn_id"] as? String).map { safeIdentifier(prefix: "tid", raw: $0) },
            phase: phase,
            label: label,
            toolCategory: toolCategory,
            projectName: Self.projectName(for: cwd, provider: provider),
            workingDirectory: cwd,
            sourceBundleID: surface == .cli
                ? (terminalBundleID ?? processIdentity?.bundleIdentifier)
                : processIdentity?.bundleIdentifier,
            sourceProcessID: processIdentity?.processID,
            sourceProcessStartedAt: processIdentity?.startedAt,
            turnStartedAt: turnStartedAt,
            updatedAt: now
        )
        try normalizedEvent.validate()
        return normalizedEvent
    }

    /// A root, empty, or relative-dot working directory has no meaningful
    /// basename, so fall back to the provider name instead of surfacing "/"
    /// as the session's project.
    private static func projectName(for cwd: String, provider: AgentProvider) -> String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        if name.isEmpty || name == "/" || name == "." {
            return provider.displayName
        }
        return name
    }

    private static func safeIdentifier(prefix: String, raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(prefix)_\(hex)"
    }
}
