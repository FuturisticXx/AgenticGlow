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
        case .userPromptSubmit, .postToolUse, .postToolUseFailure:
            phase = .thinking
            label = "Thinking"
        case .preToolUse:
            phase = .usingTool
            label = toolCategory?.label ?? "Using tool"
        case .notification, .permissionRequest:
            phase = .permission
            label = "Awaiting permission"
        case .stop:
            if (payload["status"] as? String)?.lowercased() == "error" {
                phase = .failed
                label = "Failed"
            } else {
                phase = .completed
                label = "Completed"
            }
        }

        let turnStartedAt: Date?
        switch event {
        case .userPromptSubmit:
            turnStartedAt = now
        case .sessionStart, .sessionEnd, .stop:
            turnStartedAt = nil
        case .preToolUse, .postToolUse, .postToolUseFailure, .permissionRequest, .notification:
            turnStartedAt = previous?.turnStartedAt
        }

        let terminalBundleID = environment["__CFBundleIdentifier"]
        let surface: SourceSurface = environment["TERM_PROGRAM"] == nil ? .desktop : .cli
        let normalizedEvent = NormalizedEvent(
            schemaVersion: ProductMetadata.schemaVersion,
            provider: provider,
            surface: surface,
            sessionID: sessionIdentifier(sessionID),
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
            updatedAt: now,
            model: Self.modelName(in: payload)
        )
        try normalizedEvent.validate()
        return normalizedEvent
    }

    /// A root, empty, or relative-dot working directory has no meaningful
    /// basename, so fall back to the provider name instead of surfacing "/"
    /// as the session's project.
    private static func projectName(for cwd: String, provider: AgentProvider) -> String {
        if let repository = repositoryOwningWorktree(at: cwd) {
            return repository
        }
        let name = PosixPath.lastComponent(cwd) ?? ""
        if name.isEmpty || name == "/" || name == "." {
            return provider.displayName
        }
        return name
    }

    /// An agent working in a git worktree under `<repo>/.claude/worktrees/<name>`
    /// would otherwise report the generated worktree directory, which reads
    /// nothing like the project. Lead with the repository the worktree belongs
    /// to and keep the worktree's own name after it, so two agents in two
    /// worktrees of one repository stay distinguishable.
    private static func repositoryOwningWorktree(at cwd: String) -> String? {
        let components = PosixPath.components(cwd)
        guard let marker = components.firstIndex(of: ".claude"),
              marker > 0,
              components.indices.contains(marker + 1),
              components[marker + 1] == "worktrees",
              components.indices.contains(marker + 2) else {
            return nil
        }
        let repository = components[marker - 1]
        let branch = worktreeLabel(components[marker + 2], repository: repository)
        return branch.isEmpty ? repository : "\(repository) · \(branch)"
    }

    /// Reduces `agenticglow-version-check-eaec6d` to `version-check`: the
    /// generated worktree directory repeats the repository slug and ends in a
    /// short hexadecimal id, and neither half carries meaning next to the
    /// repository name that already leads the label. A trailing segment is
    /// only treated as an id when it is hexadecimal and at least six
    /// characters, so a hand-made worktree name survives intact.
    private static func worktreeLabel(_ name: String, repository: String) -> String {
        var segments = name.split(separator: "-", omittingEmptySubsequences: false)
        if let last = segments.last,
           last.count >= 6,
           last.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
           segments.count > 1 {
            segments.removeLast()
        }
        var label = segments.joined(separator: "-")
        let prefix = repository.lowercased() + "-"
        if label.lowercased().hasPrefix(prefix) {
            label = String(label.dropFirst(prefix.count))
        } else if label.lowercased() == repository.lowercased() {
            label = ""
        }
        return label
    }

    /// Keep only a short model slug. Cursor's hook payload also includes
    /// `user_email` and `transcript_path`; those are never copied here.
    private static func modelName(in payload: [String: Any]) -> String? {
        let raw = (payload["model_id"] as? String)
            ?? (payload["model"] as? String)
        guard let raw, !raw.isEmpty, !raw.contains("\n"), raw.count <= 64 else {
            return nil
        }
        return raw
    }

    public static func sessionIdentifier(_ raw: String) -> String {
        safeIdentifier(prefix: "sid", raw: raw)
    }

    private static func safeIdentifier(prefix: String, raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(prefix)_\(hex)"
    }
}
