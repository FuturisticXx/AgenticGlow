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

    func testInstallRecordsIntegrationEnabled() async {
        let recorder = SetupRecorder()
        var recordedStates: [Bool] = []
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder,
            setIntegrationEnabled: { recordedStates.append($0) }
        )

        await model.install()

        XCTAssertEqual(recordedStates, [true])
    }

    func testRepairRecordsIntegrationEnabled() async {
        let recorder = SetupRecorder()
        var recordedStates: [Bool] = []
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder,
            setIntegrationEnabled: { recordedStates.append($0) }
        )

        await model.repair()

        XCTAssertEqual(recordedStates, [true])
    }

    func testRemoveRecordsIntegrationDisabled() {
        let recorder = SetupRecorder()
        var recordedStates: [Bool] = []
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder,
            setIntegrationEnabled: { recordedStates.append($0) }
        )

        model.remove()

        XCTAssertEqual(recordedStates, [false])
    }

    func testFailedInstallDoesNotRecordIntegrationEnabled() async {
        let recorder = SetupRecorder()
        recorder.installError = SetupRecorder.RecorderError.forced
        var recordedStates: [Bool] = []
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder,
            setIntegrationEnabled: { recordedStates.append($0) }
        )

        await model.install()

        XCTAssertTrue(recordedStates.isEmpty)
    }
}

private final class SetupRecorder:
    HelperInstalling,
    ProviderIntegrationManaging,
    SyntheticEventTesting
{
    enum RecorderError: Error {
        case forced
    }

    let destinationURL = URL(fileURLWithPath: "/tmp/agenticglow-event")
    let provider: AgentProvider = .codex
    var calls: [String] = []
    var installError: Error?

    func install() throws {
        if let installError {
            calls.append("install-helper")
            throw installError
        }
        if calls.isEmpty { calls.append("install-helper") }
        else { calls.append("install-hooks") }
    }

    func isCurrent() -> Bool { true }
    func refreshIfNeeded() throws {}
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
