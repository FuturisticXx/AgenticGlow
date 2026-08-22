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

    private func session(
        id: String,
        provider: AgentProvider = .cursor,
        phase: SessionPhase = .thinking,
        path: String,
        projectName: String? = nil
    ) -> SessionSnapshot {
        SessionSnapshot(
            provider: provider,
            surface: .desktop,
            sessionID: id,
            phase: phase,
            label: "Working",
            projectName: projectName ?? URL(fileURLWithPath: path).lastPathComponent.ifEmpty("AgenticGlow"),
            workingDirectory: path,
            sourceBundleID: nil,
            elapsedSeconds: 12,
            updatedAt: now
        )
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty || self == "/" ? fallback : self
    }
}
