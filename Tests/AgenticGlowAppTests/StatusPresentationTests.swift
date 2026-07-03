import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class StatusPresentationTests: XCTestCase {
    func testPermissionPresentationUsesAttentionStateAndCount() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 3,
                permissionCount: 2
            ),
            showTimer: true,
            reduceMotion: false
        )

        XCTAssertEqual(presentation.accessibilityLabel, "AgenticGlow, 2 sessions need permission")
        XCTAssertEqual(presentation.symbolName, "exclamationmark.circle.fill")
        XCTAssertFalse(presentation.animates)
    }

    func testWorkingPresentationShowsOptionalTimer() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 65),
            showTimer: true,
            reduceMotion: false
        )

        XCTAssertEqual(presentation.title, "1m")
        XCTAssertFalse(presentation.animates)

        let later = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 66),
            showTimer: true,
            reduceMotion: false
        )
        XCTAssertEqual(later, presentation)
    }

    func testWorkingPresentationHidesTimerWhenDisabled() {
        let early = StatusPresentation(
            resolved: resolved(phase: .usingTool, elapsedSeconds: 65),
            showTimer: false,
            reduceMotion: false
        )
        let later = StatusPresentation(
            resolved: resolved(phase: .usingTool, elapsedSeconds: 66),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertEqual(early.title, "")
        XCTAssertEqual(later, early)
    }

    func testReduceMotionKeepsWorkingPresentationStatic() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 5),
            showTimer: true,
            reduceMotion: true
        )

        XCTAssertFalse(presentation.animates)
        XCTAssertEqual(presentation.accessibilityLabel, "AgenticGlow, 1 active session")
    }

    func testIdlePresentationHasConciseAccessibilityLabel() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .idle,
                activeCount: 0,
                permissionCount: 0
            ),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertEqual(presentation.symbolName, "circle.hexagongrid")
        XCTAssertEqual(presentation.accessibilityLabel, "AgenticGlow, idle")
        XCTAssertFalse(presentation.animates)
    }

    func testCompletedAndDisconnectedPresentationsUseDistinctNonAnimatedStates() {
        let completed = StatusPresentation(
            resolved: resolved(phase: .completed, elapsedSeconds: nil),
            showTimer: true,
            reduceMotion: false
        )
        let disconnected = StatusPresentation(
            resolved: resolved(phase: .disconnected, elapsedSeconds: nil),
            showTimer: true,
            reduceMotion: false
        )

        XCTAssertEqual(completed.symbolName, "checkmark.circle.fill")
        XCTAssertEqual(completed.accessibilityLabel, "AgenticGlow, session completed")
        XCTAssertEqual(disconnected.symbolName, "bolt.slash.circle")
        XCTAssertEqual(disconnected.accessibilityLabel, "AgenticGlow, integration disconnected")
        XCTAssertFalse(completed.animates)
        XCTAssertFalse(disconnected.animates)
    }

    @MainActor
    func testSessionRowAccessibilityLabelDoesNotChangeWithElapsedTime() {
        let early = session(elapsedSeconds: 5)
        let later = session(elapsedSeconds: 65)

        let earlyLabel = SessionRowView.accessibilityLabel(for: early)
        let laterLabel = SessionRowView.accessibilityLabel(for: later)

        XCTAssertEqual(earlyLabel, "Codex, AgenticGlow, Thinking, CLI")
        XCTAssertEqual(laterLabel, earlyLabel)
        XCTAssertFalse(laterLabel.contains("1m 5s"))
    }

    private func resolved(phase: SessionPhase, elapsedSeconds: Int?) -> ResolvedSessions {
        let session = SessionSnapshot(
            provider: .codex,
            surface: .cli,
            sessionID: "session",
            phase: phase,
            label: "Status",
            projectName: "AgenticGlow",
            sourceBundleID: "com.apple.Terminal",
            elapsedSeconds: elapsedSeconds,
            updatedAt: Date()
        )
        let isActive = [SessionPhase.thinking, .usingTool, .permission].contains(phase)
        return .init(
            sessions: [session],
            dominantPhase: phase,
            activeCount: isActive ? 1 : 0,
            permissionCount: phase == .permission ? 1 : 0
        )
    }

    private func session(elapsedSeconds: Int) -> SessionSnapshot {
        SessionSnapshot(
            provider: .codex,
            surface: .cli,
            sessionID: "session",
            phase: .thinking,
            label: "Thinking",
            projectName: "AgenticGlow",
            sourceBundleID: "com.apple.Terminal",
            elapsedSeconds: elapsedSeconds,
            updatedAt: Date()
        )
    }
}
