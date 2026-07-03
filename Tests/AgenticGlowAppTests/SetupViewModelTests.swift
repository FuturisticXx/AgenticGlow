import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

@MainActor
final class SetupViewModelTests: XCTestCase {
    func testVersionDetectionDoesNotRunDuringInitialization() async {
        let recorder = SetupRecorder()
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder
        )

        XCTAssertNil(model.detectedVersion)
    }

    func testInstallRunsHelperThenProviderThenSyntheticTest() async {
        let recorder = SetupRecorder()
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder
        )

        await model.install()

        XCTAssertEqual(recorder.calls, ["install-helper", "install-hooks", "synthetic-test"])
        XCTAssertEqual(model.phase, .needsTrust)
    }
}

private final class SetupRecorder:
    HelperInstalling,
    ProviderIntegrationManaging,
    SyntheticEventTesting
{
    let destinationURL = URL(fileURLWithPath: "/tmp/agenticglow-event")
    let provider: AgentProvider = .codex
    var calls: [String] = []

    func install() throws {
        if calls.isEmpty { calls.append("install-helper") }
        else { calls.append("install-hooks") }
    }

    func isCurrent() -> Bool { true }
    func repair() throws { calls.append("repair-hooks") }
    func remove() throws { calls.append("remove-hooks") }
    func status() throws -> IntegrationStatus {
        .init(
            provider: .codex,
            installed: true,
            requiresTrustReview: true,
            installedEvents: [],
            issue: nil
        )
    }

    func run(provider: AgentProvider, helperURL: URL) throws -> Bool {
        calls.append("synthetic-test")
        return true
    }
}
