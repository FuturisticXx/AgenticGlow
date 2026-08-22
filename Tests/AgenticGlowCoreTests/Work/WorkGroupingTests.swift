import XCTest
@testable import AgenticGlowCore

final class WorkGroupingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testSamePathGroupsAcrossHarnesses() {
        let sessions = [
            session(id: "cursor", provider: .cursor, path: "/Volumes/Liquid/Caliber"),
            session(id: "claude", provider: .claude, path: "/Volumes/Liquid/Caliber/")
        ]
        let groups = WorkGrouping.groups(from: sessions)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].sessions.map(\.sessionID), ["claude", "cursor"])
        XCTAssertEqual(groups[0].presentation.displayName, "Caliber")
        XCTAssertEqual(groups[0].representative.sessionID, "claude")
    }

    func testDifferentPathsDoNotGroupEvenWithSameBasename() {
        let sessions = [
            session(id: "a", path: "/Volumes/Liquid/2DaMax Development/AgenticGlow"),
            session(id: "b", path: "/tmp/AgenticGlow")
        ]
        let groups = WorkGrouping.groups(from: sessions)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.map(\.sessions.count), [1, 1])
    }

    func testWorktreeDoesNotMergeWithMainRepo() {
        let main = "/Volumes/Liquid/2DaMax Development/Caliber Wallet"
        let worktree = "\(main)/.claude/worktrees/caliber-5-5a-composition-d702c0"
        let groups = WorkGrouping.groups(from: [
            session(id: "main", path: main),
            session(id: "tree", path: worktree)
        ])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].presentation.displayName, "Caliber Wallet")
        XCTAssertEqual(groups[1].presentation.displayName, "caliber-5-5a-composition-d702c0")
    }

    func testMissingAndInvalidPathsAreSingletons() {
        let groups = WorkGrouping.groups(from: [
            session(id: "empty", path: "", projectName: "Orphan A"),
            session(id: "relative", path: "AgenticGlow", projectName: "Orphan B"),
            session(id: "valid", path: "/tmp/AgenticGlow")
        ])
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups.map(\.sessions.count), [1, 1, 1])
        XCTAssertEqual(groups[0].presentation.displayName, "Orphan A")
        XCTAssertEqual(groups[1].presentation.displayName, "Orphan B")
        XCTAssertEqual(groups[2].presentation.displayName, "AgenticGlow")
    }

    func testDeletedPathStillGroupsByStoredString() {
        let path = "/Volumes/Gone/OldProject"
        let groups = WorkGrouping.groups(from: [
            session(id: "one", provider: .cursor, path: path),
            session(id: "two", provider: .claude, path: path)
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].presentation.displayName, "OldProject")
    }

    func testCollidingBasenamesGetParentSuffixOnLaterWork() {
        let groups = WorkGrouping.groups(from: [
            session(id: "first", path: "/Volumes/Liquid/2DaMax Development/AgenticGlow"),
            session(id: "second", path: "/tmp/scratch/AgenticGlow")
        ])
        XCTAssertEqual(groups[0].presentation.displayName, "AgenticGlow")
        XCTAssertEqual(groups[1].presentation.displayName, "AgenticGlow · scratch")
    }

    func testPermissionWorkSortsAboveWorkingWork() {
        let groups = WorkGrouping.groups(from: [
            session(id: "working", phase: .thinking, path: "/tmp/Moodpaper"),
            session(id: "needs-you", phase: .permission, path: "/tmp/AgenticGlow")
        ])
        XCTAssertEqual(groups.map(\.representative.sessionID), ["needs-you", "working"])
    }

    func testFailedDoesNotOutrankActiveToolUse() {
        let groups = WorkGrouping.groups(from: [
            session(id: "failed", phase: .failed, path: "/tmp/AgenticGlow"),
            session(id: "tool", phase: .usingTool, path: "/tmp/AgenticGlow")
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].representative.sessionID, "tool")
        XCTAssertEqual(groups[0].sessions.map(\.sessionID), ["tool", "failed"])
    }

    func testRepresentativeIsFirstInResolverOrder() {
        let groups = WorkGrouping.groups(from: [
            session(id: "idle", phase: .idle, path: "/tmp/AgenticGlow"),
            session(id: "think", phase: .thinking, path: "/tmp/AgenticGlow"),
            session(id: "ask", phase: .permission, path: "/tmp/AgenticGlow")
        ])
        XCTAssertEqual(groups[0].representative.sessionID, "ask")
    }

    func testNestedSubdirectoryIsSeparateWork() {
        let groups = WorkGrouping.groups(from: [
            session(id: "root", path: "/tmp/AgenticGlow"),
            session(id: "src", path: "/tmp/AgenticGlow/Sources")
        ])
        XCTAssertEqual(groups.count, 2)
    }

    func testSameSessionIDAndWorkCollapsesCursorAndClaudeHookReports() {
        let sid = "sid_dd1e00780b983db555e9b4a776bc48b98ca13eafb30b5dee3c79e004117e541c"
        let path = "/Volumes/Liquid/2DaMax Development/AgenticGlow"
        let claude = session(
            id: sid,
            provider: .claude,
            phase: .thinking,
            path: path,
            model: "grok-4.6"
        )
        let cursor = session(
            id: sid,
            provider: .cursor,
            phase: .usingTool,
            path: path,
            sourceBundleID: AgentProvider.cursorBundleIdentifier,
            model: "grok-4.6"
        )
        let groups = WorkGrouping.groups(from: [claude, cursor])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].sessions.count, 1)
        XCTAssertEqual(groups[0].sessions[0].provider, .cursor)
        XCTAssertEqual(groups[0].sessions[0].sessionID, sid)
        XCTAssertEqual(WorkGrouping.orderedSessions(from: [claude, cursor]).count, 1)
    }

    func testSameModelDifferentSessionIDsRemainSeparate() {
        let path = "/tmp/AgenticGlow"
        let groups = WorkGrouping.groups(from: [
            session(id: "cursor-grok", provider: .cursor, path: path, model: "grok-4.6"),
            session(id: "claude-grok", provider: .claude, path: path, model: "grok-4.6")
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].sessions.count, 2)
        XCTAssertEqual(Set(groups[0].sessions.map(\.sessionID)), ["cursor-grok", "claude-grok"])
    }

    func testSameSessionIDDifferentWorkDoesNotCollapse() {
        let sid = "sid_shared"
        let groups = WorkGrouping.groups(from: [
            session(id: sid, provider: .claude, path: "/tmp/Moodpaper", model: "grok-4.6"),
            session(
                id: sid,
                provider: .cursor,
                path: "/tmp/AgenticGlow",
                sourceBundleID: AgentProvider.cursorBundleIdentifier,
                model: "grok-4.6"
            )
        ])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.map(\.sessions.count), [1, 1])
        XCTAssertEqual(Set(groups.flatMap { $0.sessions.map(\.provider) }), [.claude, .cursor])
    }

    func testLiveNativeReportWinsOverStaleCompatibilityReport() {
        let sid = "sid_dd1e00780b983db555e9b4a776bc48b98ca13eafb30b5dee3c79e004117e541c"
        let path = "/tmp/AgenticGlow"
        let groups = WorkGrouping.groups(from: [
            session(
                id: sid,
                provider: .claude,
                phase: .thinking,
                path: path,
                updatedAt: now.addingTimeInterval(-1_200),
                model: "grok-4.6"
            ),
            session(
                id: sid,
                provider: .cursor,
                phase: .usingTool,
                path: path,
                sourceBundleID: AgentProvider.cursorBundleIdentifier,
                updatedAt: now,
                model: "grok-4.6"
            )
        ])
        let displayed = groups[0].sessions[0]
        XCTAssertEqual(groups[0].sessions.count, 1)
        XCTAssertEqual(displayed.provider, .cursor)
        XCTAssertEqual(displayed.phase, .usingTool)
        XCTAssertEqual(displayed.sourceBundleID, AgentProvider.cursorBundleIdentifier)
    }

    func testSourceReportsKeepBothAdaptersForDiagnostics() {
        let sid = "sid_dd1e00780b983db555e9b4a776bc48b98ca13eafb30b5dee3c79e004117e541c"
        let path = "/tmp/AgenticGlow"
        let claude = session(id: sid, provider: .claude, path: path, model: "grok-4.6")
        let cursor = session(
            id: sid,
            provider: .cursor,
            phase: .usingTool,
            path: path,
            sourceBundleID: AgentProvider.cursorBundleIdentifier,
            model: "grok-4.6"
        )
        let group = WorkGrouping.groups(from: [claude, cursor])[0]
        XCTAssertEqual(group.sessions.count, 1)
        XCTAssertEqual(group.sessions[0].provider, .cursor)
        XCTAssertEqual(Set(group.sourceReports.map(\.provider)), [.claude, .cursor])
        XCTAssertEqual(group.sourceReports.count, 2)
        XCTAssertEqual(Set(group.sourceReports.map(\.sessionID)), [sid])
    }

    private func session(
        id: String,
        provider: AgentProvider = .cursor,
        phase: SessionPhase = .thinking,
        path: String,
        projectName: String? = nil,
        sourceBundleID: String? = nil,
        updatedAt: Date? = nil,
        model: String? = nil
    ) -> SessionSnapshot {
        SessionSnapshot(
            provider: provider,
            surface: .desktop,
            sessionID: id,
            phase: phase,
            label: "Working",
            projectName: projectName ?? URL(fileURLWithPath: path).lastPathComponent.ifEmpty("AgenticGlow"),
            workingDirectory: path,
            sourceBundleID: sourceBundleID,
            elapsedSeconds: 12,
            updatedAt: updatedAt ?? now,
            model: model
        )
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty || self == "/" ? fallback : self
    }
}
