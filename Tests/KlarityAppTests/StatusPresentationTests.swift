import XCTest
@testable import Klarity
@testable import KlarityCore

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

        XCTAssertEqual(presentation.accessibilityLabel, "Klarity, 2 sessions need permission")
        XCTAssertEqual(presentation.symbolName, "exclamationmark.circle.fill")
        XCTAssertFalse(presentation.animates)
    }

    func testWorkingPresentationShowsOptionalTimer() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 65),
            showTimer: true,
            reduceMotion: false
        )

        XCTAssertEqual(presentation.title, "1m 5s")
        XCTAssertTrue(presentation.animates)
    }

    func testWorkingPresentationHidesTimerWhenDisabled() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .usingTool, elapsedSeconds: 65),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertEqual(presentation.title, "")
    }

    func testReduceMotionKeepsWorkingPresentationStatic() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 5),
            showTimer: true,
            reduceMotion: true
        )

        XCTAssertFalse(presentation.animates)
        XCTAssertEqual(presentation.accessibilityLabel, "Klarity, 1 active session")
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
        XCTAssertEqual(presentation.accessibilityLabel, "Klarity, idle")
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
        XCTAssertEqual(completed.accessibilityLabel, "Klarity, session completed")
        XCTAssertEqual(disconnected.symbolName, "bolt.slash.circle")
        XCTAssertEqual(disconnected.accessibilityLabel, "Klarity, integration disconnected")
        XCTAssertFalse(completed.animates)
        XCTAssertFalse(disconnected.animates)
    }

    private func resolved(phase: SessionPhase, elapsedSeconds: Int?) -> ResolvedSessions {
        let session = SessionSnapshot(
            provider: .codex,
            surface: .cli,
            sessionID: "session",
            phase: phase,
            label: "Status",
            projectName: "Klarity",
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
}
