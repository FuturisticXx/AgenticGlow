import Foundation
import KlarityCore

enum UITestFixtureFactory {
    static func events(arguments: [String]) -> [NormalizedEvent]? {
        guard let index = arguments.firstIndex(of: "--ui-test-fixture"),
              arguments.indices.contains(index + 1) else { return nil }
        switch arguments[index + 1] {
        case "empty":
            return []
        case "permission":
            return [
                .init(
                    schemaVersion: 1,
                    provider: .claude,
                    surface: .desktop,
                    sessionID: "ui-permission",
                    turnID: "turn",
                    phase: .permission,
                    label: "Awaiting permission",
                    toolCategory: nil,
                    projectName: "Example",
                    workingDirectory: "/tmp/Example",
                    sourceBundleID: "com.anthropic.claudefordesktop",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                ),
                .init(
                    schemaVersion: 1,
                    provider: .codex,
                    surface: .cli,
                    sessionID: "ui-working",
                    turnID: "turn",
                    phase: .thinking,
                    label: "Thinking",
                    toolCategory: nil,
                    projectName: "Klarity",
                    workingDirectory: "/tmp/Klarity",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                )
            ]
        default:
            return nil
        }
    }
}

final class UITestSessionStore: SessionStateStoring {
    private var events: [NormalizedEvent]

    init(events: [NormalizedEvent]) {
        self.events = events
    }

    func write(_ event: NormalizedEvent) {
        events.removeAll { SessionKey($0) == SessionKey(event) }
        events.append(event)
    }

    func loadAll() -> [NormalizedEvent] { events }
    func load(_ key: SessionKey) -> NormalizedEvent? {
        events.first { SessionKey($0) == key }
    }
    func remove(_ key: SessionKey) {
        events.removeAll { SessionKey($0) == key }
    }
}
