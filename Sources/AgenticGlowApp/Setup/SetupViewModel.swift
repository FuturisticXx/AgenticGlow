import Foundation
import Observation
import AgenticGlowCore

enum SetupPhase: Equatable {
    case unavailable
    case ready
    case installing
    case needsTrust
    case installed
    case failed(String)
}

@MainActor
@Observable
final class SetupViewModel {
    let provider: AgentProvider
    let executableURL: URL?
    private(set) var detectedVersion: String?
    private let helperInstaller: HelperInstalling
    private let integration: ProviderIntegrationManaging
    private let syntheticEventService: SyntheticEventTesting
    private let lastEvent: () -> Date?
    var phase: SetupPhase
    var integrationStatus: IntegrationStatus?
    var lastEventAt: Date?

    init(
        provider: AgentProvider,
        executableURL: URL?,
        helperInstaller: HelperInstalling,
        integration: ProviderIntegrationManaging,
        syntheticEventService: SyntheticEventTesting,
        lastEvent: @escaping () -> Date? = { nil }
    ) {
        self.provider = provider
        self.executableURL = executableURL
        self.detectedVersion = nil
        self.helperInstaller = helperInstaller
        self.integration = integration
        self.syntheticEventService = syntheticEventService
        self.lastEvent = lastEvent
        self.phase = executableURL == nil ? .unavailable : .ready
    }

    func detectVersion() async {
        guard let executableURL else { return }
        detectedVersion = await Task.detached {
            ProviderVersionDetector.detect(executableURL: executableURL)
        }.value
    }

    func install() async {
        phase = .installing
        do {
            try helperInstaller.install()
            try integration.install()
            guard try syntheticEventService.run(
                provider: provider,
                helperURL: helperInstaller.destinationURL
            ) else {
                phase = .failed("AgenticGlow did not receive the local test event.")
                return
            }
            phase = provider == .codex ? .needsTrust : .installed
            refreshDiagnostics()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func repair() async {
        phase = .installing
        do {
            try helperInstaller.install()
            try integration.repair()
            phase = provider == .codex ? .needsTrust : .installed
            refreshDiagnostics()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func remove() {
        do {
            try integration.remove()
            phase = executableURL == nil ? .unavailable : .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func refreshDiagnostics() {
        integrationStatus = try? integration.status()
        lastEventAt = lastEvent()
    }
}
