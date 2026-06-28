import Foundation
import Observation
import KlarityCore

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
    let detectedVersion: String?
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
        self.detectedVersion = executableURL.flatMap(ProviderVersionDetector.detect)
        self.helperInstaller = helperInstaller
        self.integration = integration
        self.syntheticEventService = syntheticEventService
        self.lastEvent = lastEvent
        self.phase = executableURL == nil ? .unavailable : .ready
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
                phase = .failed("Klarity did not receive the local test event.")
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
