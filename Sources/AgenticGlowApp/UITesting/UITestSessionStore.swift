import Foundation
import AgenticGlowCore

enum UITestFixtureFactory {
    static func name(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--ui-test-fixture"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static func events(arguments: [String]) -> [NormalizedEvent]? {
        switch name(arguments: arguments) {
        case "empty", "setup-repair", "allowance-unavailable":
            return []
        case "permission", "signals":
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
                    projectName: "AgenticGlow",
                    workingDirectory: "/tmp/AgenticGlow",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                )
            ]
        case "both-working":
            return [
                .init(
                    schemaVersion: 1,
                    provider: .claude,
                    surface: .cli,
                    sessionID: "both-claude",
                    turnID: "turn",
                    phase: .thinking,
                    label: "Thinking",
                    toolCategory: nil,
                    projectName: "horizon-app",
                    workingDirectory: "/tmp/horizon-app",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                ),
                .init(
                    schemaVersion: 1,
                    provider: .codex,
                    surface: .cli,
                    sessionID: "both-codex",
                    turnID: "turn",
                    phase: .usingTool,
                    label: "Editing main.swift",
                    toolCategory: .edit,
                    projectName: "AgenticGlow",
                    workingDirectory: "/tmp/AgenticGlow",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                )
            ]
        case "permission-and-working":
            return [
                .init(
                    schemaVersion: 1,
                    provider: .claude,
                    surface: .desktop,
                    sessionID: "mix-permission",
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
                    provider: .claude,
                    surface: .cli,
                    sessionID: "mix-claude-thinking",
                    turnID: "turn",
                    phase: .thinking,
                    label: "Thinking",
                    toolCategory: nil,
                    projectName: "horizon-app",
                    workingDirectory: "/tmp/horizon-app",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                ),
                .init(
                    schemaVersion: 1,
                    provider: .codex,
                    surface: .cli,
                    sessionID: "mix-codex-building",
                    turnID: "turn",
                    phase: .usingTool,
                    label: "Editing main.swift",
                    toolCategory: .edit,
                    projectName: "AgenticGlow",
                    workingDirectory: "/tmp/AgenticGlow",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                )
            ]
        case "redesign-states":
            return [
                .init(
                    schemaVersion: 1,
                    provider: .claude,
                    surface: .cli,
                    sessionID: "redesign-working",
                    turnID: "turn",
                    phase: .usingTool,
                    label: "Editing StatusItemController.swift",
                    toolCategory: .edit,
                    projectName: "agenticglow",
                    workingDirectory: "/tmp/agenticglow",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date().addingTimeInterval(-54),
                    updatedAt: Date()
                ),
                .init(
                    schemaVersion: 1,
                    provider: .codex,
                    surface: .cli,
                    sessionID: "redesign-permission",
                    turnID: "turn",
                    phase: .permission,
                    label: "Awaiting permission",
                    toolCategory: nil,
                    projectName: "permisight",
                    workingDirectory: "/tmp/permisight",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                ),
                .init(
                    schemaVersion: 1,
                    provider: .claude,
                    surface: .cli,
                    sessionID: "redesign-failed",
                    turnID: "turn",
                    phase: .failed,
                    label: "Running swift build",
                    toolCategory: nil,
                    projectName: "weather-widget",
                    workingDirectory: "/tmp/weather-widget",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: nil,
                    updatedAt: Date().addingTimeInterval(-120)
                ),
                .init(
                    schemaVersion: 1,
                    provider: .codex,
                    surface: .cli,
                    sessionID: "redesign-completed",
                    turnID: "turn",
                    phase: .completed,
                    label: "Completed",
                    toolCategory: nil,
                    projectName: "2damax-site",
                    workingDirectory: "/tmp/2damax-site",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: nil,
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
    let destinationURL = URL(fileURLWithPath: "/tmp/agenticglow-event")
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

/// Deterministic low allowance for the "signals" fixture: 8% left in the
/// current window and 5% left in the week, so badge and bars are provable.
struct UITestAllowanceAdapter: AllowanceProviding {
    let provider: AgentProvider

    func fetch() async throws -> ProviderAllowance {
        ProviderAllowance(
            provider: provider,
            currentWindowLabel: "5h",
            currentPercentUsed: 92,
            currentResetAt: Date().addingTimeInterval(2 * 3_600),
            weeklyPercentUsed: 95,
            weeklyResetAt: Date().addingTimeInterval(3 * 86_400),
            fetchedAt: Date()
        )
    }
}

/// Canned status payloads for the "signals" fixture: Claude reports an
/// incident, Codex reports operational.
struct UITestStatusRequester: ProviderStatusRequesting {
    func fetchStatus(for provider: AgentProvider) async throws -> Data {
        if provider == .claude {
            return Data(#"{"status":{"indicator":"minor","description":"Elevated errors on Claude"}}"#.utf8)
        }
        return Data(#"{"status":{"indicator":"none","description":"All Systems Operational"}}"#.utf8)
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
