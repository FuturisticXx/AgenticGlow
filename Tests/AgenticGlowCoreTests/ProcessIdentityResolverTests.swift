import XCTest
@testable import AgenticGlowCore

final class ProcessIdentityResolverTests: XCTestCase {
    func testResolvesCodexCLI() {
        let inspector = FakeProcessInspector(
            parentPID: 30,
            rows: [
                30: .init(pid: 30, parentPID: 20, name: "zsh", startedAt: Date(timeIntervalSince1970: 30), bundleID: nil),
                20: .init(pid: 20, parentPID: 10, name: "codex", startedAt: Date(timeIntervalSince1970: 20), bundleID: nil),
                10: .init(pid: 10, parentPID: 1, name: "Terminal", startedAt: Date(timeIntervalSince1970: 10), bundleID: "com.apple.Terminal")
            ]
        )
        let resolver = ProcessIdentityResolver(inspector: inspector)

        let identity = resolver.resolve(
            provider: .codex,
            environment: ["TERM_PROGRAM": "Apple_Terminal", "__CFBundleIdentifier": "com.apple.Terminal"]
        )

        XCTAssertEqual(identity?.processID, 20)
        XCTAssertEqual(identity?.startedAt, Date(timeIntervalSince1970: 20))
        XCTAssertEqual(identity?.bundleIdentifier, "com.apple.Terminal")
    }

    func testDoesNotReturnUnrelatedAncestor() {
        let inspector = FakeProcessInspector(
            parentPID: 30,
            rows: [30: .init(pid: 30, parentPID: 1, name: "zsh", startedAt: nil, bundleID: nil)]
        )
        XCTAssertNil(ProcessIdentityResolver(inspector: inspector).resolve(
            provider: .claude,
            environment: [:]
        ))
    }

    func testFindsTerminalBundleFromAncestorWhenEnvironmentOmitsIt() {
        let inspector = FakeProcessInspector(
            parentPID: 20,
            rows: [
                20: .init(pid: 20, parentPID: 10, name: "codex", startedAt: Date(timeIntervalSince1970: 20), bundleID: nil),
                10: .init(pid: 10, parentPID: 1, name: "Terminal", startedAt: Date(timeIntervalSince1970: 10), bundleID: "com.apple.Terminal")
            ]
        )
        let identity = ProcessIdentityResolver(inspector: inspector).resolve(
            provider: .codex,
            environment: ["TERM_PROGRAM": "Apple_Terminal"]
        )
        XCTAssertEqual(identity?.bundleIdentifier, "com.apple.Terminal")
    }

    func testResolvesClaudeCodeCLI() {
        let inspector = FakeProcessInspector(
            parentPID: 30,
            rows: [
                30: .init(pid: 30, parentPID: 20, name: "zsh", startedAt: nil, bundleID: nil),
                20: .init(pid: 20, parentPID: 10, name: "claude", startedAt: Date(timeIntervalSince1970: 20), bundleID: nil),
                10: .init(pid: 10, parentPID: 1, name: "iTerm2", startedAt: nil, bundleID: "com.googlecode.iterm2")
            ]
        )

        let identity = ProcessIdentityResolver(inspector: inspector).resolve(
            provider: .claude,
            environment: [
                "TERM_PROGRAM": "iTerm.app",
                "__CFBundleIdentifier": "com.googlecode.iterm2"
            ]
        )

        XCTAssertEqual(identity?.processID, 20)
        XCTAssertEqual(identity?.bundleIdentifier, "com.googlecode.iterm2")
    }

    func testResolvesCodexDesktopExecutableAndMainAppWhileIgnoringServiceAndHelperNames() {
        let inspector = FakeProcessInspector(
            parentPID: 60,
            rows: [
                60: .init(pid: 60, parentPID: 50, name: "Codex (Service)", startedAt: nil, bundleID: "com.openai.codex.service"),
                50: .init(pid: 50, parentPID: 40, name: "codex", startedAt: Date(timeIntervalSince1970: 50), bundleID: nil),
                40: .init(pid: 40, parentPID: 30, name: "Codex Helper", startedAt: nil, bundleID: "com.openai.codex.helper"),
                30: .init(pid: 30, parentPID: 1, name: "Codex", startedAt: Date(timeIntervalSince1970: 30), bundleID: "com.openai.codex")
            ]
        )

        let identity = ProcessIdentityResolver(inspector: inspector).resolve(
            provider: .codex,
            environment: [:]
        )

        XCTAssertEqual(identity?.processID, 50)
        XCTAssertEqual(identity?.startedAt, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(identity?.bundleIdentifier, "com.openai.codex")
    }

    func testResolvesClaudeDesktopExecutableAndMainAppWhileIgnoringHelperNames() {
        let inspector = FakeProcessInspector(
            parentPID: 60,
            rows: [
                60: .init(pid: 60, parentPID: 50, name: "Claude Helper", startedAt: nil, bundleID: "com.anthropic.claudefordesktop.helper"),
                50: .init(pid: 50, parentPID: 40, name: "claude", startedAt: Date(timeIntervalSince1970: 50), bundleID: nil),
                40: .init(pid: 40, parentPID: 30, name: "Claude Helper (Renderer)", startedAt: nil, bundleID: "com.anthropic.claudefordesktop.renderer"),
                30: .init(pid: 30, parentPID: 1, name: "Claude", startedAt: Date(timeIntervalSince1970: 30), bundleID: "com.anthropic.claudefordesktop")
            ]
        )

        let identity = ProcessIdentityResolver(inspector: inspector).resolve(
            provider: .claude,
            environment: [:]
        )

        XCTAssertEqual(identity?.processID, 50)
        XCTAssertEqual(identity?.startedAt, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(identity?.bundleIdentifier, "com.anthropic.claudefordesktop")
    }

    func testSelfParentTraversalStopsWithoutResolvingAnUnrelatedProcess() {
        let inspector = FakeProcessInspector(
            parentPID: 99,
            rows: [
                99: .init(pid: 99, parentPID: 99, name: "zsh", startedAt: nil, bundleID: nil)
            ]
        )

        XCTAssertNil(ProcessIdentityResolver(inspector: inspector).resolve(
            provider: .codex,
            environment: [:]
        ))
    }

    func testProcessMonitorAcceptsMatchingStartTime() {
        let processID = Int32(ProcessInfo.processInfo.processIdentifier)
        let startedAt = Date(timeIntervalSince1970: 100)
        let inspector = FakeProcessInspector(
            parentPID: 1,
            rows: [
                processID: .init(
                    pid: processID,
                    parentPID: 1,
                    name: "AgenticGlowCoreTests",
                    startedAt: startedAt,
                    bundleID: nil
                )
            ]
        )

        XCTAssertTrue(DarwinProcessMonitor(inspector: inspector).isAlive(
            processID: processID,
            startedAt: startedAt
        ))
    }

    func testProcessMonitorRejectsReusedPIDWithDifferentStartTime() {
        let processID = Int32(ProcessInfo.processInfo.processIdentifier)
        let inspector = FakeProcessInspector(
            parentPID: 1,
            rows: [
                processID: .init(
                    pid: processID,
                    parentPID: 1,
                    name: "AgenticGlowCoreTests",
                    startedAt: Date(timeIntervalSince1970: 100),
                    bundleID: nil
                )
            ]
        )

        XCTAssertFalse(DarwinProcessMonitor(inspector: inspector).isAlive(
            processID: processID,
            startedAt: Date(timeIntervalSince1970: 200)
        ))
    }

    func testProcessMonitorRejectsSubsecondStartTimeMismatch() {
        let processID = Int32(ProcessInfo.processInfo.processIdentifier)
        let inspector = FakeProcessInspector(
            parentPID: 1,
            rows: [
                processID: .init(
                    pid: processID,
                    parentPID: 1,
                    name: "AgenticGlowCoreTests",
                    startedAt: Date(timeIntervalSince1970: 100.123_456),
                    bundleID: nil
                )
            ]
        )

        XCTAssertFalse(DarwinProcessMonitor(inspector: inspector).isAlive(
            processID: processID,
            startedAt: Date(timeIntervalSince1970: 100.123_956)
        ))
    }

    func testSourceApplicationActivatorRejectsNilBundle() {
        let activator = SourceApplicationActivator(activateBundle: { _ in true })

        XCTAssertFalse(activator.activate(bundleIdentifier: nil))
    }

    func testSourceApplicationActivatorDelegatesBundleActivation() {
        let activator = SourceApplicationActivator(activateBundle: { bundleIdentifier in
            bundleIdentifier == "com.openai.codex"
        })

        XCTAssertTrue(activator.activate(bundleIdentifier: "com.openai.codex"))
        XCTAssertFalse(activator.activate(bundleIdentifier: "com.example.missing"))
    }
}

private struct FakeProcessInspector: ProcessInspecting {
    let parentPID: Int32
    let rows: [Int32: InspectedProcess]
    var currentParentPID: Int32 { parentPID }
    func process(_ pid: Int32) -> InspectedProcess? { rows[pid] }
}
