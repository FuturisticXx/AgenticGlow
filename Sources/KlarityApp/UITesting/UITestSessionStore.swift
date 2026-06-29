import Foundation
import KlarityCore

enum UITestFixtureFactory {
    static func name(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--ui-test-fixture"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static func events(arguments: [String]) -> [NormalizedEvent]? {
        switch name(arguments: arguments) {
        case "empty", "setup-repair":
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

    @MainActor
    static func setupRepairModels(arguments: [String]) -> (
        claude: SetupViewModel,
        codex: SetupViewModel
    )? {
        guard name(arguments: arguments) == "setup-repair" else { return nil }
        let claude = UITestSetupRecorder(provider: .claude)
        let codex = UITestSetupRecorder(provider: .codex)
        return (
            SetupViewModel(
                provider: .claude,
                executableURL: URL(fileURLWithPath: "/tmp/claude"),
                helperInstaller: claude,
                integration: claude,
                syntheticEventService: claude
            ),
            SetupViewModel(
                provider: .codex,
                executableURL: URL(fileURLWithPath: "/tmp/codex"),
                helperInstaller: codex,
                integration: codex,
                syntheticEventService: codex
            )
        )
    }
}

private final class UITestSetupRecorder:
    HelperInstalling,
    ProviderIntegrationManaging,
    SyntheticEventTesting
{
    let destinationURL = URL(fileURLWithPath: "/tmp/klarity-event")
    let provider: AgentProvider

    init(provider: AgentProvider) {
        self.provider = provider
    }

    func install() throws {}
    func isCurrent() -> Bool { true }
    func repair() throws {}
    func remove() throws {}
    func run(provider: AgentProvider, helperURL: URL) throws -> Bool { true }
    func status() throws -> IntegrationStatus {
        .init(
            provider: provider,
            installed: true,
            requiresTrustReview: provider == .codex,
            installedEvents: HookEventKind.allCases,
            issue: nil
        )
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
