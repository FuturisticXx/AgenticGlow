import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class StatusPresentationTests: XCTestCase {
    func testPermissionPresentationUsesAttentionStateAndCount() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 2,
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

    func testWorkingPresentationShowsHoursAboveOneHour() {
        let mixed = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 3_665),
            showTimer: true,
            reduceMotion: false
        )
        XCTAssertEqual(mixed.title, "1h 1m")

        let exact = StatusPresentation(
            resolved: resolved(phase: .thinking, elapsedSeconds: 7_200),
            showTimer: true,
            reduceMotion: false
        )
        XCTAssertEqual(exact.title, "2h")
    }

    @MainActor
    func testSessionRowTimerShowsHoursAboveOneHour() {
        XCTAssertEqual(SessionRowView.format(59), "59s")
        XCTAssertEqual(SessionRowView.format(3_599), "59m 59s")
        XCTAssertEqual(SessionRowView.format(3_665), "1h 1m")
        XCTAssertEqual(SessionRowView.format(7_200), "2h")
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

    @MainActor
    func testAccessibilityValueIncludesElapsedTimeWhileThinking() {
        let value = SessionRowView.accessibilityValue(for: session(elapsedSeconds: 65))
        XCTAssertEqual(value, "1m 5s")
    }

    @MainActor
    func testAccessibilityValueIsNilWhenNotActivelyWorking() {
        let idle = SessionSnapshot(
            provider: .codex,
            surface: .cli,
            sessionID: "idle",
            phase: .idle,
            label: "Idle",
            projectName: "AgenticGlow",
            sourceBundleID: "com.apple.Terminal",
            elapsedSeconds: 65,
            updatedAt: Date()
        )
        XCTAssertNil(SessionRowView.accessibilityValue(for: idle))
    }

    @MainActor
    func testAccessibilityValueIsNilWithoutElapsedSeconds() {
        let noElapsed = SessionSnapshot(
            provider: .codex,
            surface: .cli,
            sessionID: "no-elapsed",
            phase: .usingTool,
            label: "Using tool",
            projectName: "AgenticGlow",
            sourceBundleID: "com.apple.Terminal",
            elapsedSeconds: nil,
            updatedAt: Date()
        )
        XCTAssertNil(SessionRowView.accessibilityValue(for: noElapsed))
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

    func testActiveProviderIsClaudeOnly() {
        let presentation = working(activeProviders: [.claude])
        XCTAssertEqual(presentation.activeProviders, [.claude])
    }

    func testActiveProviderIsCodexOnly() {
        let presentation = working(activeProviders: [.codex])
        XCTAssertEqual(presentation.activeProviders, [.codex])
    }

    func testActiveProvidersAreBothInClaudeThenCodexOrder() {
        let presentation = working(activeProviders: [.codex, .claude])
        XCTAssertEqual(presentation.activeProviders, [.claude, .codex])
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
        XCTAssertTrue(presentation.activeProviders.isEmpty)
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
        XCTAssertTrue(presentation.activeProviders.isEmpty)
    }

    func testPermissionWithWorkersPulsesAndKeepsProviders() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 3,
                permissionCount: 1,
                activeProviders: [.codex, .claude]
            ),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertTrue(presentation.pulsesPermission)
        XCTAssertEqual(presentation.activeProviders, [.claude, .codex])
        XCTAssertTrue(presentation.animates)
        XCTAssertEqual(presentation.symbolName, "exclamationmark.circle.fill")
        XCTAssertEqual(
            presentation.accessibilityLabel,
            "AgenticGlow, 1 session needs permission, 2 active sessions"
        )
    }

    func testPermissionWithOneWorkerReadsSingularActiveSession() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 2,
                permissionCount: 1,
                activeProviders: [.codex]
            ),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertTrue(presentation.pulsesPermission)
        XCTAssertEqual(presentation.activeProviders, [.codex])
        XCTAssertEqual(
            presentation.accessibilityLabel,
            "AgenticGlow, 1 session needs permission, 1 active session"
        )
    }

    func testPermissionWithWorkersUnderReduceMotionStaysStatic() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 3,
                permissionCount: 1,
                activeProviders: [.codex, .claude]
            ),
            showTimer: false,
            reduceMotion: true
        )

        XCTAssertFalse(presentation.pulsesPermission)
        XCTAssertTrue(presentation.activeProviders.isEmpty)
        XCTAssertFalse(presentation.animates)
    }

    func testPermissionAloneDoesNotPulse() {
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

        XCTAssertFalse(presentation.pulsesPermission)
        XCTAssertTrue(presentation.activeProviders.isEmpty)
        XCTAssertFalse(presentation.animates)
        XCTAssertEqual(
            presentation.accessibilityLabel,
            "AgenticGlow, 1 session needs permission"
        )
    }

    func testWorkingStateDoesNotPulsePermission() {
        let presentation = working(activeProviders: [.claude, .codex])
        XCTAssertFalse(presentation.pulsesPermission)
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
