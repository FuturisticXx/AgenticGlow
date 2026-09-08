import XCTest
@testable import AgenticGlowCore

/// Covers the idle visibility lifecycle end to end through the resolver,
/// which is the canonical layer every active-session surface reads from.
/// Time is injected, so nothing here waits.
final class SessionVisibilityPolicyTests: XCTestCase {
    private let window = SessionVisibilityPolicy.idleVisibilityWindow

    func testWindowIsTenMinutes() {
        XCTAssertEqual(SessionVisibilityPolicy.idleVisibilityWindow, 600)
    }

    func testToolWindowIsOneHour() {
        XCTAssertEqual(SessionVisibilityPolicy.toolVisibilityWindow, 3_600)
    }

    func testOnlyToolUseGetsTheLongerWindow() {
        XCTAssertEqual(SessionVisibilityPolicy.activityWindow(for: .usingTool), 3_600)
        for phase in [SessionPhase.idle, .thinking, .permission, .completed, .failed, .disconnected] {
            XCTAssertEqual(
                SessionVisibilityPolicy.activityWindow(for: phase),
                600,
                "\(phase) should use the idle window"
            )
        }
    }

    // MARK: A long-running tool is not a dead session

    /// A build or test run that outlasts the idle window emits PreToolUse and
    /// then nothing until it finishes. That is evidence of work in progress,
    /// not silence after work stopped, so the row must stay put.
    func testLongRunningToolStaysVisiblePastTheIdleWindow() {
        for minutes in [11, 20, 45, 59] {
            let resolved = resolve(
                event(session: "long-build", phase: .usingTool, updated: 1_000),
                now: 1_000 + TimeInterval(minutes * 60)
            )
            XCTAssertEqual(
                resolved.sessions.first?.phase,
                .usingTool,
                "hidden after \(minutes) minutes of one tool call"
            )
            XCTAssertEqual(resolved.activeCount, 1)
        }
    }

    func testToolUseExpiresAtTheToolWindow() {
        let justUnder = resolve(
            event(session: "long-build", phase: .usingTool, updated: 1_000),
            now: 1_000 + SessionVisibilityPolicy.toolVisibilityWindow - 1
        )
        XCTAssertEqual(justUnder.sessions.first?.phase, .usingTool)

        let atCutoff = resolve(
            event(session: "long-build", phase: .usingTool, updated: 1_000),
            now: 1_000 + SessionVisibilityPolicy.toolVisibilityWindow
        )
        XCTAssertTrue(atCutoff.sessions.isEmpty)
    }

    /// The longer window is scoped to the tool phase alone: a session that
    /// stopped after its tool finished still expires at ten minutes.
    func testThinkingDoesNotInheritTheToolWindow() {
        let resolved = resolve(
            event(session: "stalled", phase: .thinking, updated: 1_000),
            now: 1_000 + window + 1
        )
        XCTAssertTrue(resolved.sessions.isEmpty)
    }

    /// The real stale row in the wild: a session that died holding
    /// usingTool. Twelve hours later it must still be gone.
    func testToolSessionAbandonedForHoursIsHidden() {
        let resolved = resolve(
            event(session: "abandoned", phase: .usingTool, updated: 1_000),
            now: 1_000 + 12 * 60 * 60
        )
        XCTAssertTrue(resolved.sessions.isEmpty)
    }

    // MARK: Lifecycle

    func testContinuouslyActiveSessionStaysVisible() {
        var memory = ResolutionMemory()
        // Each turn writes a fresh event, so the window never elapses even
        // though the session has been running far longer than ten minutes.
        for minute in stride(from: 0, through: 60, by: 5) {
            let updated = 1_000 + TimeInterval(minute * 60)
            let resolved = SessionResolver.resolve(
                events: [event(session: "busy", phase: .thinking, updated: updated)],
                now: Date(timeIntervalSince1970: updated + 1),
                memory: &memory,
                isProcessAlive: { _, _ in true }
            )
            XCTAssertEqual(resolved.sessions.count, 1, "hidden at minute \(minute)")
            XCTAssertEqual(resolved.activeCount, 1)
        }
    }

    func testIdleJustUnderTheWindowStaysVisible() {
        let resolved = resolve(
            event(session: "quiet", phase: .idle, updated: 1_000),
            now: 1_000 + window - 1
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .idle)
    }

    func testIdleExactlyAtTheWindowIsHidden() {
        let resolved = resolve(
            event(session: "quiet", phase: .idle, updated: 1_000),
            now: 1_000 + window
        )
        XCTAssertTrue(resolved.sessions.isEmpty)
    }

    func testIdleBeyondTheWindowStaysHidden() {
        let resolved = resolve(
            event(session: "quiet", phase: .idle, updated: 1_000),
            now: 1_000 + window * 4
        )
        XCTAssertTrue(resolved.sessions.isEmpty)
    }

    func testHiddenSessionReappearsWhenActivityResumes() {
        var memory = ResolutionMemory()
        let stale = event(session: "resumes", phase: .idle, updated: 1_000)

        let hidden = SessionResolver.resolve(
            events: [stale],
            now: Date(timeIntervalSince1970: 1_000 + window + 60),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertTrue(hidden.sessions.isEmpty)

        // A new prompt writes a new event for the same key. No restart, no
        // manual restore, and the same memory carries forward.
        let resumed = SessionResolver.resolve(
            events: [event(session: "resumes", phase: .thinking, updated: 1_000 + window + 61)],
            now: Date(timeIntervalSince1970: 1_000 + window + 62),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(resumed.sessions.first?.phase, .thinking)
        XCTAssertEqual(resumed.activeCount, 1)
    }

    // MARK: Attention is exempt

    func testPermissionStaysVisibleFarBeyondTheWindow() {
        let resolved = resolve(
            event(session: "waiting", phase: .permission, updated: 1_000),
            now: 1_000 + window * 6
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .permission)
        XCTAssertEqual(resolved.permissionCount, 1)
    }

    func testPermissionSurvivesAlongsideHiddenIdleSiblings() {
        let resolved = resolve(
            event(session: "waiting", phase: .permission, updated: 1_000),
            event(session: "stale-a", phase: .idle, updated: 1_000),
            event(session: "stale-b", phase: .thinking, updated: 1_000),
            now: 1_000 + window + 1
        )
        XCTAssertEqual(resolved.sessions.map(\.sessionID), ["waiting"])
        XCTAssertEqual(resolved.activeCount, 1)
        XCTAssertEqual(resolved.dominantPhase, .permission)
    }

    // MARK: Termination and restart

    func testSessionTerminatingBeforeTheWindowStillShowsDisconnected() {
        var memory = ResolutionMemory()
        let ev = event(session: "ended", phase: .idle, updated: 1_000)

        let dying = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 1_060),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(dying.sessions.first?.phase, .disconnected)

        let gone = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 1_060 + SessionResolver.disconnectedDisplayDuration + 1),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(gone.sessions.isEmpty)
    }

    /// Death observed after the session was already hidden is a real state
    /// change, so the brief Disconnected notice is still allowed to show.
    func testProcessDeathObservedAfterHidingUsesDetectionTime() {
        var memory = ResolutionMemory()
        let ev = event(session: "late-death", phase: .idle, updated: 1_000)

        let hidden = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 1_000 + window + 1),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertTrue(hidden.sessions.isEmpty)

        let died = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 1_000 + window + 2),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(died.sessions.first?.phase, .disconnected)
    }

    /// Restart rebuilds visibility from the stored events alone, so a
    /// session idle across a relaunch is hidden without any carried state.
    func testRestartWithIdleSessionResolvesHiddenFromFilesAlone() {
        let stored = event(session: "across-restart", phase: .idle, updated: 1_000)
        var freshMemory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [stored],
            now: Date(timeIntervalSince1970: 1_000 + window + 1),
            memory: &freshMemory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertTrue(resolved.sessions.isEmpty)

        var recentMemory = ResolutionMemory()
        let recent = SessionResolver.resolve(
            events: [stored],
            now: Date(timeIntervalSince1970: 1_000 + 30),
            memory: &recentMemory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(recent.sessions.count, 1)
    }

    // MARK: Meaningless events do not extend visibility

    /// Re-resolving the same unchanged event is what the 2s refresh, the
    /// Codex poll, and every widget sync actually do. None of them may
    /// keep a stale session alive.
    func testRepeatedResolutionOfUnchangedEventDoesNotExtendVisibility() {
        var memory = ResolutionMemory()
        let ev = event(session: "polled", phase: .idle, updated: 1_000)

        for second in stride(from: 0, to: window, by: 2) {
            let resolved = SessionResolver.resolve(
                events: [ev],
                now: Date(timeIntervalSince1970: 1_000 + second),
                memory: &memory,
                isProcessAlive: { _, _ in true }
            )
            XCTAssertEqual(resolved.sessions.count, 1, "vanished early at +\(second)s")
        }

        let expired = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 1_000 + window),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertTrue(expired.sessions.isEmpty)
    }

    // MARK: Grouping, dedup, and multi-model surfaces

    func testDuplicateReportsOfOneStaleSessionAllDisappearTogether() {
        let resolved = resolve(
            event(session: "shared", provider: .claude, phase: .idle, updated: 1_000),
            event(session: "shared", provider: .cursor, phase: .idle, updated: 1_000),
            now: 1_000 + window + 1
        )
        XCTAssertTrue(resolved.sessions.isEmpty)
        XCTAssertTrue(WorkGrouping.groups(from: resolved.sessions).isEmpty)
    }

    /// Hiding is per session, not per work: a stale sibling leaves the row
    /// while its still-working partner in the same folder stays.
    func testStaleSiblingLeavesTheGroupWithoutRemovingTheWork() {
        let resolved = resolve(
            event(session: "live", provider: .claude, phase: .thinking, updated: 1_000 + window),
            event(session: "stale", provider: .codex, phase: .idle, updated: 1_000),
            now: 1_000 + window + 1
        )
        let groups = WorkGrouping.groups(from: resolved.sessions)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.sessions.map(\.sessionID), ["live"])
    }

    func testModelSummaryDropsModelsRepresentedOnlyByStaleSessions() {
        let resolved = resolve(
            event(session: "live", provider: .claude, phase: .thinking, updated: 1_000 + window, model: "claude-opus-4-5"),
            event(session: "stale", provider: .codex, phase: .idle, updated: 1_000, model: "gpt-5-codex"),
            now: 1_000 + window + 1
        )
        let models = Set(resolved.sessions.compactMap(\.model))
        XCTAssertEqual(models, ["claude-opus-4-5"])
        XCTAssertEqual(resolved.activeProviders, [.claude])
    }

    /// Several sessions sharing one model collapse to nothing once all of
    /// them go stale, so the count cannot report phantom activity.
    func testSharedModelSessionsAllExpireIndependently() {
        let resolved = resolve(
            event(session: "a", provider: .claude, phase: .thinking, updated: 1_000, model: "claude-opus-4-5"),
            event(session: "b", provider: .claude, phase: .thinking, updated: 1_000, model: "claude-opus-4-5"),
            event(session: "c", provider: .claude, phase: .thinking, updated: 1_000 + window, model: "claude-opus-4-5"),
            now: 1_000 + window + 1
        )
        XCTAssertEqual(resolved.sessions.map(\.sessionID), ["c"])
        XCTAssertEqual(resolved.activeCount, 1)
    }

    // MARK: Timestamp anomalies

    func testFutureTimestampIsTreatedAsRecentRatherThanHidden() {
        let resolved = resolve(
            event(session: "skewed", phase: .idle, updated: 5_000),
            now: 1_000
        )
        XCTAssertEqual(resolved.sessions.count, 1)
    }
}

private let window = SessionVisibilityPolicy.idleVisibilityWindow

private func resolve(_ events: NormalizedEvent..., now: TimeInterval) -> ResolvedSessions {
    var memory = ResolutionMemory()
    return SessionResolver.resolve(
        events: events,
        now: Date(timeIntervalSince1970: now),
        memory: &memory,
        isProcessAlive: { _, _ in true }
    )
}

private func event(
    session: String,
    provider: AgentProvider = .claude,
    phase: SessionPhase,
    updated: TimeInterval,
    model: String? = nil
) -> NormalizedEvent {
    NormalizedEvent(
        schemaVersion: ProductMetadata.schemaVersion,
        provider: provider,
        surface: .cli,
        sessionID: session,
        turnID: nil,
        phase: phase,
        label: phase.rawValue,
        toolCategory: nil,
        projectName: "Fixture",
        workingDirectory: "/tmp/fixture",
        sourceBundleID: "com.apple.Terminal",
        sourceProcessID: 42,
        sourceProcessStartedAt: Date(timeIntervalSince1970: 1),
        turnStartedAt: phase.isActive ? Date(timeIntervalSince1970: updated) : nil,
        updatedAt: Date(timeIntervalSince1970: updated),
        model: model
    )
}
