import XCTest
@testable import KlarityCore

final class ProcessIdentityResolverTests: XCTestCase {
    func testFindsNearestCodexAncestorAndKeepsTerminalBundleForActivation() {
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

    func testProcessMonitorAcceptsMatchingStartTime() {
        let processID = Int32(ProcessInfo.processInfo.processIdentifier)
        let startedAt = Date(timeIntervalSince1970: 100)
        let inspector = FakeProcessInspector(
            parentPID: 1,
            rows: [
                processID: .init(
                    pid: processID,
                    parentPID: 1,
                    name: "KlarityCoreTests",
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
                    name: "KlarityCoreTests",
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
}

private struct FakeProcessInspector: ProcessInspecting {
    let parentPID: Int32
    let rows: [Int32: InspectedProcess]
    var currentParentPID: Int32 { parentPID }
    func process(_ pid: Int32) -> InspectedProcess? { rows[pid] }
}
