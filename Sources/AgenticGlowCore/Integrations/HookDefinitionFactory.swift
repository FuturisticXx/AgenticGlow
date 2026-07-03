import Foundation

public enum HookDefinitionFactory {
    public static let marker = "--agenticglow-hook"

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
        let requiresMatcher = [.preToolUse, .postToolUse, .permissionRequest].contains(event)
        if requiresMatcher {
            guard group["matcher"] as? String == "*" else { return false }
        } else if group["matcher"] != nil {
            return false
        }
        let expected = HookDefinitionFactory.command(
            helperURL: helperURL,
            provider: provider,
            event: event
        )
        return try handlers(in: group).contains {
            $0["type"] as? String == "command"
                && $0["command"] as? String == expected
                && ($0["timeout"] as? NSNumber)?.intValue == 5
        }
    }

    static func removingManagedHandlers(
        from hooks: [String: Any],
        provider: AgentProvider
    ) throws -> [String: Any] {
        var updatedHooks = hooks
        for key in hooks.keys {
            let groups = try validatedGroups(hooks[key] as Any)
            let updatedGroups: [[String: Any]] = try groups.compactMap { group -> [String: Any]? in
                var updatedGroup = group
                let remaining = try handlers(in: group).filter {
                    !isManagedHandler($0, provider: provider)
                }
                guard !remaining.isEmpty else { return nil }
                updatedGroup["hooks"] = remaining
                return updatedGroup
            }
            if updatedGroups.isEmpty {
                updatedHooks.removeValue(forKey: key)
            } else {
                updatedHooks[key] = updatedGroups
            }
        }
        return updatedHooks
    }

    static func hasManagedHandlers(
        in hooks: [String: Any],
        provider: AgentProvider
    ) throws -> Bool {
        try hooks.values.contains { value in
            try validatedGroups(value).contains { group in
                try handlers(in: group).contains {
                    isManagedHandler($0, provider: provider)
                }
            }
        }
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
        provider: AgentProvider
    ) -> Bool {
        guard handler["type"] as? String == "command",
              let command = handler["command"] as? String,
              let parsed = parseManagedCommand(command),
              parsed.provider == provider,
              URL(fileURLWithPath: parsed.path).lastPathComponent == "agenticglow-event" else {
            return false
        }
        return true
    }

    private static func parseManagedCommand(
        _ command: String
    ) -> (path: String, provider: AgentProvider, event: String)? {
        let characters = Array(command)
        guard let quote = characters.first, quote == "'" || quote == "\"" else { return nil }

        var path = ""
        var index = 1
        var foundClosingQuote = false
        while index < characters.count {
            if characters[index] != quote {
                path.append(characters[index])
                index += 1
                continue
            }
            if quote == "'",
               index + 3 < characters.count,
               characters[index] == "'",
               characters[index + 1] == "\\",
               characters[index + 2] == "'",
               characters[index + 3] == "'" {
                path.append("'")
                index += 4
                continue
            }
            foundClosingQuote = true
            index += 1
            break
        }

        guard foundClosingQuote,
              path.hasPrefix("/"),
              index < characters.count,
              characters[index] == " " else {
            return nil
        }
        let suffix = String(characters[(index + 1)...])
        let tokens = suffix.split(separator: " ", omittingEmptySubsequences: false)
        guard tokens.count == 3,
              let provider = AgentProvider(rawValue: String(tokens[0])),
              !tokens[1].isEmpty,
              tokens[1].allSatisfy({ !$0.isWhitespace }),
              tokens[2] == Substring(HookDefinitionFactory.marker) else {
            return nil
        }
        return (path, provider, String(tokens[1]))
    }
}
