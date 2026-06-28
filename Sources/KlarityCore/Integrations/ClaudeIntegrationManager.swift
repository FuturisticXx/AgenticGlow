import Foundation

public final class ClaudeIntegrationManager: ProviderIntegrationManaging {
    public let provider: AgentProvider = .claude

    private let settingsURL: URL
    private let helperURL: URL
    private let events: [HookEventKind] = [
        .sessionStart, .sessionEnd, .userPromptSubmit, .preToolUse,
        .postToolUse, .notification, .permissionRequest, .stop
    ]

    public init(settingsURL: URL, helperURL: URL) {
        self.settingsURL = settingsURL
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
            provider: .claude,
            installed: complete,
            requiresTrustReview: false,
            installedEvents: installedEvents,
            issue: complete ? nil : "Claude hooks need installation or repair."
        )
    }

    private func rewrite(add: Bool) throws {
        let editor = JSONConfigEditor(url: settingsURL)
        if !add {
            guard let object = try editor.readObjectIfPresent() else { return }
            let hooks = try HookConfiguration.validatedHooks(in: object)
            guard try HookConfiguration.hasManagedHandlers(
                in: hooks,
                provider: .claude,
                events: events
            ) else { return }
        }

        try editor.mutate { object in
            var hooks = try HookConfiguration.validatedHooks(in: object)
            for event in events {
                let groups = try HookConfiguration.groups(for: event, in: hooks)
                var updated = try HookConfiguration.removingManagedHandlers(
                    from: groups,
                    provider: .claude,
                    event: event
                )
                if add {
                    updated.append(HookDefinitionFactory.entry(
                        helperURL: helperURL,
                        provider: .claude,
                        event: event
                    ))
                }
                if updated.isEmpty {
                    hooks.removeValue(forKey: event.rawValue)
                } else {
                    hooks[event.rawValue] = updated
                }
            }
            object["hooks"] = hooks
        }
    }

    private func installedEvents() throws -> [HookEventKind] {
        let editor = JSONConfigEditor(url: settingsURL)
        guard let object = try editor.readObjectIfPresent() else { return [] }
        let hooks = try HookConfiguration.validatedHooks(in: object)
        return try events.filter { event in
            try HookConfiguration.groups(for: event, in: hooks).contains {
                try HookConfiguration.containsCurrentHook(
                    $0,
                    helperURL: helperURL,
                    provider: .claude,
                    event: event
                )
            }
        }
    }
}
