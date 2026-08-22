import XCTest
@testable import AgenticGlowCore

final class WorkStatusLineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testSingleSessionUsesCurrentPhaseCopy() {
        let group = only(session(id: "one", phase: .thinking, model: "grok-4.6"))
        XCTAssertEqual(WorkStatusLine.compact(for: group), "Thinking")
    }

    func testSinglePermissionAndFailedKeepExistingCopy() {
        XCTAssertEqual(
            WorkStatusLine.compact(for: only(session(id: "ask", phase: .permission))),
            "Needs you"
        )
        XCTAssertEqual(
            WorkStatusLine.compact(for: only(session(id: "dead", phase: .failed))),
            "Stopped while working"
        )
    }

    func testMultiSessionActiveLineUsesShortModelSlugs() {
        let group = WorkGrouping.groups(from: [
            session(id: "g", model: "grok-4.6"),
            session(id: "c", provider: .claude, model: "claude-sonnet-5-thinking-high"),
            session(id: "p", model: "composer-2.5-fast")
        ])[0]
        XCTAssertEqual(
            WorkStatusLine.compact(for: group),
            "3 active · Claude, Grok, Composer"
        )
    }

    func testUnknownModelFallsBackToHarnessName() {
        let group = WorkGrouping.groups(from: [
            session(id: "a", provider: .cursor, model: nil),
            session(id: "b", provider: .codex, model: nil)
        ])[0]
        XCTAssertEqual(
            WorkStatusLine.compact(for: group),
            "2 active · Codex, Cursor"
        )
    }

    func testSharedSlugAcrossHarnessesKeepsHarness() {
        let group = WorkGrouping.groups(from: [
            session(id: "cursor-grok", provider: .cursor, model: "grok-4.6"),
            session(id: "claude-grok", provider: .claude, model: "grok-4.6")
        ])[0]
        XCTAssertEqual(
            WorkStatusLine.compact(for: group),
            "2 active · Grok (Claude), Grok (Cursor)"
        )
    }

    func testUnknownSlugShowsAsIs() {
        let group = WorkGrouping.groups(from: [
            session(id: "a", model: "mystery-model-9"),
            session(id: "b", model: "other")
        ])[0]
        XCTAssertEqual(
            WorkStatusLine.compact(for: group),
            "2 active · mystery-model-9, other"
        )
    }

    func testMultiSessionPermissionKeepsNeedsYou() {
        let group = WorkGrouping.groups(from: [
            session(id: "ask", phase: .permission, model: "grok-4.6"),
            session(id: "think", phase: .thinking, model: "composer-2.5-fast")
        ])[0]
        XCTAssertEqual(WorkStatusLine.compact(for: group), "Needs you")
    }

    private func only(_ session: SessionSnapshot) -> WorkGrouping.Group {
        WorkGrouping.groups(from: [session])[0]
    }

    private func session(
        id: String,
        provider: AgentProvider = .cursor,
        phase: SessionPhase = .thinking,
        model: String? = nil
    ) -> SessionSnapshot {
        SessionSnapshot(
            provider: provider,
            surface: .desktop,
            sessionID: id,
            phase: phase,
            label: "Working",
            projectName: "AgenticGlow",
            workingDirectory: "/tmp/AgenticGlow",
            sourceBundleID: nil,
            elapsedSeconds: 12,
            updatedAt: now,
            model: model
        )
    }
}
