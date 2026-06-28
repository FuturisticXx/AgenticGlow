import Foundation

public enum HookDefinitionFactory {
    public static let marker = "--klarity-hook"

    public static func command(
        helperURL: URL,
        provider: AgentProvider,
        event: HookEventKind
    ) -> String {
        let escapedPath = helperURL.path.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escapedPath)' \(provider.rawValue) \(event.rawValue) \(marker)"
    }

    public static func entry(
        helperURL: URL,
        provider: AgentProvider,
        event: HookEventKind
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": command(helperURL: helperURL, provider: provider, event: event),
                "timeout": 5
            ]]
        ]
        if [.preToolUse, .postToolUse, .permissionRequest].contains(event) {
            entry["matcher"] = "*"
        }
        return entry
    }
}

enum HookConfiguration {
    static func validatedHooks(in object: [String: Any]) throws -> [String: Any] {
        guard let value = object["hooks"] else { return [:] }
        guard let hooks = value as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        for value in hooks.values {
            _ = try validatedGroups(value)
        }
        return hooks
    }

    static func groups(
        for event: HookEventKind,
        in hooks: [String: Any]
    ) throws -> [[String: Any]] {
        guard let value = hooks[event.rawValue] else { return [] }
        return try validatedGroups(value)
    }

    static func handlers(in group: [String: Any]) throws -> [[String: Any]] {
        guard let value = group["hooks"], let values = value as? [Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return try values.map {
            guard let handler = $0 as? [String: Any] else {
                throw CocoaError(.propertyListReadCorrupt)
            }
            return handler
        }
    }

    static func containsCurrentHook(
        _ group: [String: Any],
        helperURL: URL,
        provider: AgentProvider,
        event: HookEventKind
    ) throws -> Bool {
        let expected = HookDefinitionFactory.command(
            helperURL: helperURL,
            provider: provider,
            event: event
        )
        return try handlers(in: group).contains {
            $0["type"] as? String == "command" && $0["command"] as? String == expected
        }
    }

    static func removingManagedHandlers(
        from groups: [[String: Any]],
        provider: AgentProvider,
        event: HookEventKind
    ) throws -> [[String: Any]] {
        try groups.compactMap { group in
            var updated = group
            let remaining = try handlers(in: group).filter {
                !isManagedHandler($0, provider: provider, event: event)
            }
            guard !remaining.isEmpty else { return nil }
            updated["hooks"] = remaining
            return updated
        }
    }

    static func hasManagedHandlers(
        in hooks: [String: Any],
        provider: AgentProvider,
        events: [HookEventKind]
    ) throws -> Bool {
        for event in events {
            let eventGroups = try groups(for: event, in: hooks)
            for group in eventGroups where try handlers(in: group).contains(where: {
                isManagedHandler($0, provider: provider, event: event)
            }) {
                return true
            }
        }
        return false
    }

    private static func validatedGroups(_ value: Any) throws -> [[String: Any]] {
        guard let values = value as? [Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return try values.map {
            guard let group = $0 as? [String: Any] else {
                throw CocoaError(.propertyListReadCorrupt)
            }
            _ = try handlers(in: group)
            return group
        }
    }

    private static func isManagedHandler(
        _ handler: [String: Any],
        provider: AgentProvider,
        event: HookEventKind
    ) -> Bool {
        guard handler["type"] as? String == "command",
              let command = handler["command"] as? String else {
            return false
        }
        return command.hasSuffix(
            " \(provider.rawValue) \(event.rawValue) \(HookDefinitionFactory.marker)"
        )
    }
}
