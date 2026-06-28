import Foundation

public final class CodexIntegrationManager: ProviderIntegrationManaging {
    public static let trustInstruction =
        "Open Codex, run /hooks, review the Klarity entries, and choose Trust."

    public let provider: AgentProvider = .codex

    private let hooksURL: URL
    private let helperURL: URL
    private let events: [HookEventKind] = [
        .sessionStart, .userPromptSubmit, .preToolUse,
        .postToolUse, .permissionRequest, .stop
    ]

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
            provider: .codex,
            installed: complete,
            requiresTrustReview: !installedEvents.isEmpty,
            installedEvents: installedEvents,
            issue: complete ? Self.trustInstruction : "Codex hooks need installation or repair."
        )
    }

    private func rewrite(add: Bool) throws {
        let editor = JSONConfigEditor(url: hooksURL)
        if !add {
            guard let object = try editor.readObjectIfPresent() else { return }
            let hooks = try HookConfiguration.validatedHooks(in: object)
            guard try HookConfiguration.hasManagedHandlers(
                in: hooks,
                provider: .codex
            ) else { return }
        }

        try editor.mutate { object in
            let existingHooks = try HookConfiguration.validatedHooks(in: object)
            var hooks = try HookConfiguration.removingManagedHandlers(
                from: existingHooks,
                provider: .codex
            )
            for event in events {
                var updated = try HookConfiguration.groups(for: event, in: hooks)
                if add {
                    updated.append(HookDefinitionFactory.entry(
                        helperURL: helperURL,
                        provider: .codex,
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
        let editor = JSONConfigEditor(url: hooksURL)
        guard let object = try editor.readObjectIfPresent() else { return [] }
        let hooks = try HookConfiguration.validatedHooks(in: object)
        return try events.filter { event in
            try HookConfiguration.groups(for: event, in: hooks).contains {
                try HookConfiguration.containsCurrentHook(
                    $0,
                    helperURL: helperURL,
                    provider: .codex,
                    event: event
                )
            }
        }
    }
}
