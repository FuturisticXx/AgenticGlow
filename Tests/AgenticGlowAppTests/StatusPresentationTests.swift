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
                permissionCount: 2,
                activeProviders: []
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
        XCTAssertEqual(presentation.symbolName, "circle.hexagongrid")
        XCTAssertTrue(presentation.animates)

        let later = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 66),
            showTimer: true,
            reduceMotion: false
        )
        XCTAssertEqual(later, presentation)
    }

    func testWorkingPresentationShowsSecondsBelowOneMinute() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 54),
            showTimer: true,
            reduceMotion: false
        )

        XCTAssertEqual(presentation.title, "54s")
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
        XCTAssertTrue(early.animates)
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
                permissionCount: 0,
                activeProviders: []
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

    func testLowAllowanceShowsBadgeAndExtendsAccessibility() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .idle, elapsedSeconds: nil),
            showTimer: false,
            reduceMotion: false,
            lowAllowance: true
        )

        XCTAssertTrue(presentation.showsAllowanceBadge)
        XCTAssertEqual(presentation.accessibilityLabel, "AgenticGlow, idle, usage low")
    }

    func testHealthyAllowanceShowsNoBadgeByDefault() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .idle, elapsedSeconds: nil),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertFalse(presentation.showsAllowanceBadge)
        XCTAssertEqual(presentation.accessibilityLabel, "AgenticGlow, idle")
    }

    func testBadgeCoexistsWithPermissionPhase() {
        let presentation = StatusPresentation(
            resolved: resolved(phase: .permission, elapsedSeconds: nil),
            showTimer: false,
            reduceMotion: false,
            lowAllowance: true
        )

        XCTAssertTrue(presentation.showsAllowanceBadge)
        XCTAssertEqual(presentation.symbolName, "exclamationmark.circle.fill")
        XCTAssertEqual(
            presentation.accessibilityLabel,
            "AgenticGlow, 1 session needs permission, usage low"
        )
    }

    func testActiveTintIsClaudeOnlyOrange() {
        let presentation = working(activeProviders: [.claude])
        XCTAssertEqual(presentation.activeTints, [ProviderColor.nsColor(for: .claude)])
    }

    func testActiveTintIsCodexOnlyAzure() {
        let presentation = working(activeProviders: [.codex])
        XCTAssertEqual(presentation.activeTints, [ProviderColor.nsColor(for: .codex)])
    }

    func testActiveTintIsBothInClaudeThenCodexOrder() {
        let presentation = working(activeProviders: [.codex, .claude])
        XCTAssertEqual(
            presentation.activeTints,
            [ProviderColor.nsColor(for: .claude), ProviderColor.nsColor(for: .codex)]
        )
    }

    func testPermissionHasNoProviderTints() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 1,
                permissionCount: 1,
                activeProviders: []
            ),
            showTimer: false,
            reduceMotion: false
        )
        XCTAssertTrue(presentation.activeTints.isEmpty)
    }

    func testIdleHasNoProviderTints() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .idle,
                activeCount: 0,
                permissionCount: 0,
                activeProviders: []
            ),
            showTimer: false,
            reduceMotion: false
        )
        XCTAssertTrue(presentation.activeTints.isEmpty)
    }

    private func working(activeProviders: Set<AgentProvider>) -> StatusPresentation {
        StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .thinking,
                activeCount: activeProviders.count,
                permissionCount: 0,
                activeProviders: activeProviders
            ),
            showTimer: false,
            reduceMotion: false
        )
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
            permissionCount: phase == .permission ? 1 : 0,
            activeProviders: [.thinking, .usingTool].contains(phase) ? [.codex] : []
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
