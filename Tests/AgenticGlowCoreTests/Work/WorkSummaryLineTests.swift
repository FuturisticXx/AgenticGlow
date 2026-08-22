import XCTest
@testable import AgenticGlowCore

final class WorkSummaryLineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testSinglePermissionWithoutOverlapKeepsCurrentCopy() {
        let resolved = resolved([
            session(id: "ask", phase: .permission, path: "/tmp/Example")
        ], permissionCount: 1)
        XCTAssertEqual(WorkSummaryLine.popover(resolved: resolved), "1 agent needs you")
    }

    func testOverlappingPermissionNamesTheWork() {
        let resolved = resolved([
            session(id: "ask", phase: .permission, path: "/tmp/AgenticGlow"),
            session(id: "think", phase: .thinking, path: "/tmp/AgenticGlow")
        ], permissionCount: 1, activeProviders: [.cursor])
        XCTAssertEqual(WorkSummaryLine.popover(resolved: resolved), "AgenticGlow needs you")
    }

    func testTwoWorksNeedingYouKeepCount() {
        let resolved = resolved([
            session(id: "a", phase: .permission, path: "/tmp/AgenticGlow"),
            session(id: "b", phase: .permission, path: "/tmp/Moodpaper")
        ], permissionCount: 2)
        XCTAssertEqual(WorkSummaryLine.popover(resolved: resolved), "2 agents need you")
    }

    func testOverlappingActiveSessionsNameTheWork() {
        let resolved = resolved([
            session(id: "one", path: "/tmp/AgenticGlow"),
            session(id: "two", path: "/tmp/AgenticGlow"),
            session(id: "three", path: "/tmp/AgenticGlow"),
            session(id: "four", path: "/tmp/AgenticGlow")
        ], activeProviders: [.cursor])
        XCTAssertEqual(WorkSummaryLine.popover(resolved: resolved), "AgenticGlow working")
    }

    func testSingleActiveSessionKeepsProviderCopy() {
        let resolved = resolved([
            session(id: "one", provider: .cursor, path: "/tmp/AgenticGlow")
        ], activeProviders: [.cursor])
        XCTAssertEqual(WorkSummaryLine.popover(resolved: resolved), "Cursor working")
    }

    func testTwoWorksStayOnProviderCopy() {
        let resolved = resolved([
            session(id: "a", provider: .cursor, path: "/tmp/AgenticGlow"),
            session(id: "b", provider: .claude, path: "/tmp/Moodpaper")
        ], activeProviders: [.cursor, .claude])
        XCTAssertEqual(WorkSummaryLine.popover(resolved: resolved), "Claude and Cursor working")
    }

    func testIdleCountUnchanged() {
        let resolved = resolved([
            session(id: "one", phase: .idle, path: "/tmp/AgenticGlow")
        ])
        XCTAssertEqual(WorkSummaryLine.popover(resolved: resolved), "1 session")
    }

    func testOrderedSessionsKeepSiblingsTogether() {
        let sessions = [
            session(id: "glow-ask", phase: .permission, path: "/tmp/AgenticGlow"),
            session(id: "mood", phase: .thinking, path: "/tmp/Moodpaper"),
            session(id: "glow-think", phase: .thinking, path: "/tmp/AgenticGlow")
        ]
        XCTAssertEqual(
            WorkGrouping.orderedSessions(from: sessions).map(\.sessionID),
            ["glow-ask", "glow-think", "mood"]
        )
    }

    private func resolved(
        _ sessions: [SessionSnapshot],
        permissionCount: Int = 0,
        activeProviders: Set<AgentProvider> = []
    ) -> ResolvedSessions {
        ResolvedSessions(
            sessions: sessions,
            dominantPhase: sessions.first?.phase ?? .idle,
            activeCount: sessions.filter { $0.phase.isActive || $0.phase == .permission }.count,
            permissionCount: permissionCount,
            activeProviders: activeProviders
        )
    }

    private func session(
        id: String,
        provider: AgentProvider = .cursor,
        phase: SessionPhase = .thinking,
        path: String
    ) -> SessionSnapshot {
        SessionSnapshot(
            provider: provider,
            surface: .desktop,
            sessionID: id,
            phase: phase,
            label: "Working",
            projectName: URL(fileURLWithPath: path).lastPathComponent,
            workingDirectory: path,
            sourceBundleID: nil,
            elapsedSeconds: 12,
            updatedAt: now
        )
    }
}
