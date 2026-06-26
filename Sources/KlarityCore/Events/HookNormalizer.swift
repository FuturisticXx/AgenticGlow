import Foundation

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
            let isPermission = notificationType == "permission_prompt"
                || message.contains("permission")
                || message.contains("approve")
                || message.contains("allow")
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
        default:
            turnStartedAt = previous?.turnStartedAt ?? now
        }

        let terminalBundleID = environment["__CFBundleIdentifier"]
        let surface: SourceSurface = environment["TERM_PROGRAM"] == nil ? .desktop : .cli
        let normalizedEvent = NormalizedEvent(
            schemaVersion: ProductMetadata.schemaVersion,
            provider: provider,
            surface: surface,
            sessionID: sanitizedID(sessionID),
            turnID: payload["turn_id"] as? String,
            phase: phase,
            label: label,
            toolCategory: toolCategory,
            projectName: URL(fileURLWithPath: cwd).lastPathComponent,
            workingDirectory: cwd,
            sourceBundleID: surface == .cli ? terminalBundleID : processIdentity?.bundleIdentifier,
            sourceProcessID: processIdentity?.processID,
            sourceProcessStartedAt: processIdentity?.startedAt,
            turnStartedAt: turnStartedAt,
            updatedAt: now
        )
        try normalizedEvent.validate()
        return normalizedEvent
    }

    private static func sanitizedID(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return String(raw.unicodeScalars.filter(allowed.contains).prefix(128))
    }
}
