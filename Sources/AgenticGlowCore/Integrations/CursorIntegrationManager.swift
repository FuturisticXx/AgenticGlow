import Foundation

public final class CursorIntegrationManager: ProviderIntegrationManaging {
    public let provider: AgentProvider = .cursor

    private let hooksURL: URL
    private let helperURL: URL
    private let events: [HookEventKind] = HookEventKind.cursorEvents

    public init(hooksURL: URL, helperURL: URL) {
        self.hooksURL = hooksURL
        self.helperURL = helperURL
    }

    public func install() throws {
        try rewrite(add: true)
    }

    public func repair() throws {
        try rewrite(add: true)
    }

    public func remove() throws {
        try rewrite(add: false)
    }

    public func status() throws -> IntegrationStatus {
        let installedEvents = try installedEvents()
        let complete = installedEvents == events
        return IntegrationStatus(
            provider: .cursor,
            installed: complete,
            requiresTrustReview: false,
            installedEvents: installedEvents,
            issue: complete ? nil : "Cursor hooks need installation or repair."
        )
    }

    private func rewrite(add: Bool) throws {
        let editor = JSONConfigEditor(url: hooksURL)
        if !add {
            guard let object = try editor.readObjectIfPresent() else { return }
            let hooks = try CursorHookConfiguration.validatedHooks(in: object)
            guard try CursorHookConfiguration.hasManagedHandlers(
                in: hooks,
                provider: .cursor
            ) else { return }
        }

        try editor.mutate { object in
            if object["version"] == nil {
                object["version"] = 1
            }
            let existingHooks = try CursorHookConfiguration.validatedHooks(in: object)
            var hooks = try CursorHookConfiguration.removingManagedHandlers(
                from: existingHooks,
                provider: .cursor
            )
            for event in events {
                var updated = try CursorHookConfiguration.entries(for: event, in: hooks)
                if add {
                    updated.append(HookDefinitionFactory.cursorEntry(
                        helperURL: helperURL,
                        provider: .cursor,
                        event: event
                    ))
                }
                if updated.isEmpty {
                    hooks.removeValue(forKey: event.cursorHookName)
                } else {
                    hooks[event.cursorHookName] = updated
                }
            }
            object["hooks"] = hooks
        }
    }

    private func installedEvents() throws -> [HookEventKind] {
        let editor = JSONConfigEditor(url: hooksURL)
        guard let object = try editor.readObjectIfPresent() else { return [] }
        let hooks = try CursorHookConfiguration.validatedHooks(in: object)
        return try events.filter { event in
            try CursorHookConfiguration.entries(for: event, in: hooks).contains {
                try CursorHookConfiguration.containsCurrentHook(
                    $0,
                    helperURL: helperURL,
                    provider: .cursor,
                    event: event
                )
            }
        }
    }
}

enum CursorHookConfiguration {
    static func validatedHooks(in object: [String: Any]) throws -> [String: Any] {
        guard let value = object["hooks"] else { return [:] }
        guard let hooks = value as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        for value in hooks.values {
            _ = try validatedEntries(value)
        }
        return hooks
    }

    static func entries(
        for event: HookEventKind,
        in hooks: [String: Any]
    ) throws -> [[String: Any]] {
        guard let value = hooks[event.cursorHookName] else { return [] }
        return try validatedEntries(value)
    }

    static func containsCurrentHook(
        _ entry: [String: Any],
        helperURL: URL,
        provider: AgentProvider,
        event: HookEventKind
    ) throws -> Bool {
        let expected = HookDefinitionFactory.command(
            helperURL: helperURL,
            provider: provider,
            event: event
        )
        return entry["command"] as? String == expected
            && (entry["timeout"] as? NSNumber)?.intValue == 5
            && entry["failClosed"] == nil
    }

    static func removingManagedHandlers(
        from hooks: [String: Any],
        provider: AgentProvider
    ) throws -> [String: Any] {
        var updatedHooks = hooks
        for key in hooks.keys {
            let remaining = try validatedEntries(hooks[key] as Any).filter {
                !isManagedHandler($0, provider: provider)
            }
            if remaining.isEmpty {
                updatedHooks.removeValue(forKey: key)
            } else {
                updatedHooks[key] = remaining
            }
        }
        return updatedHooks
    }

    static func hasManagedHandlers(
        in hooks: [String: Any],
        provider: AgentProvider
    ) throws -> Bool {
        try hooks.values.contains { value in
            try validatedEntries(value).contains {
                isManagedHandler($0, provider: provider)
            }
        }
    }

    private static func validatedEntries(_ value: Any) throws -> [[String: Any]] {
        guard let values = value as? [Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return try values.map {
            guard let entry = $0 as? [String: Any] else {
                throw CocoaError(.propertyListReadCorrupt)
            }
            return entry
        }
    }

    private static func isManagedHandler(
        _ entry: [String: Any],
        provider: AgentProvider
    ) -> Bool {
        guard let command = entry["command"] as? String,
              let parsed = HookConfiguration.parseManagedCommand(command),
              parsed.provider == provider,
              URL(fileURLWithPath: parsed.path).lastPathComponent == "agenticglow-event" else {
            return false
        }
        return true
    }
}
