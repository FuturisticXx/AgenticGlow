import XCTest
@testable import AgenticGlowCore

final class SessionResolverTests: XCTestCase {
    func testPermissionOutranksWorkingAndCompleted() {
        let now = Date(timeIntervalSince1970: 1_000)
        let events = [
            event(provider: .codex, session: "working", phase: .usingTool, updated: 999),
            event(provider: .claude, session: "permission", phase: .permission, updated: 998),
            event(provider: .codex, session: "done", phase: .completed, updated: 997)
        ]
        var memory = ResolutionMemory()

        let resolved = SessionResolver.resolve(
            events: events,
            now: now,
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )

        XCTAssertEqual(resolved.dominantPhase, .permission)
        XCTAssertEqual(resolved.permissionCount, 1)
        XCTAssertEqual(resolved.sessions.map(\.sessionID), ["permission", "working", "done"])
    }

    func testCompletedBecomesIdleAfterEightSeconds() {
        let event = event(provider: .codex, session: "done", phase: .completed, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 109),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .idle)
    }

    func testDeadProcessMidTaskBecomesFailed() {
        let event = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .failed)

        let expired = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_016),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(expired.sessions.isEmpty)
    }

    func testDeadProcessMidToolUseBecomesFailed() {
        let event = event(provider: .codex, session: "dead-tool", phase: .usingTool, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .failed)
    }

    func testDeadProcessAfterCompletionStaysDisconnected() {
        let event = event(provider: .claude, session: "done", phase: .completed, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .disconnected)
    }

    func testDeadProcessFromIdleStaysDisconnected() {
        let event = event(provider: .claude, session: "idle", phase: .idle, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .disconnected)
    }

    func testFailedSessionPreservesLastActionLabel() {
        let event = event(provider: .codex, session: "dead-tool", phase: .usingTool, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(resolved.sessions.first?.label, "usingTool")
    }

    func testFailedOutranksCompletedInDominantPhase() {
        let events = [
            deadPidEvent(pid: 43, provider: .claude, session: "failed", phase: .thinking, updated: 998),
            event(provider: .codex, session: "done", phase: .completed, updated: 997)
        ]
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: events,
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { pid, _ in pid == 42 }
        )
        XCTAssertEqual(resolved.dominantPhase, .failed)
        XCTAssertEqual(resolved.sessions.map(\.sessionID), ["failed", "done"])
    }

    func testActiveSessionOutranksFailedInDominantPhase() {
        let events = [
            event(provider: .codex, session: "working", phase: .usingTool, updated: 999),
            deadPidEvent(pid: 43, provider: .claude, session: "failed", phase: .thinking, updated: 998)
        ]
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: events,
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { pid, _ in pid == 42 }
        )
        XCTAssertEqual(resolved.dominantPhase, .usingTool)
        XCTAssertEqual(resolved.sessions.map(\.sessionID), ["working", "failed"])
    }

    func testExpiredDeadEventStaysHiddenOnRepeatedResolution() {
        let deadEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        var memory = ResolutionMemory()

        _ = SessionResolver.resolve(
            events: [deadEvent],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )

        let expired = SessionResolver.resolve(
            events: [deadEvent],
            now: Date(timeIntervalSince1970: 1_016),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(expired.sessions.isEmpty)

        let repeated = SessionResolver.resolve(
            events: [deadEvent],
            now: Date(timeIntervalSince1970: 1_017),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(repeated.sessions.isEmpty)
    }

    func testNewDeadEventWithSameKeyGetsFreshFailedWindowAfterOlderEventExpires() {
        let oldEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        let newEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 1_005)
        var memory = ResolutionMemory()

        let initial = SessionResolver.resolve(
            events: [oldEvent],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(initial.sessions.first?.phase, .failed)

        let expired = SessionResolver.resolve(
            events: [oldEvent],
            now: Date(timeIntervalSince1970: 1_016),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(expired.sessions.isEmpty)

        let refreshed = SessionResolver.resolve(
            events: [newEvent],
            now: Date(timeIntervalSince1970: 1_016),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(refreshed.sessions.first?.phase, .failed)

        let stillVisible = SessionResolver.resolve(
            events: [newEvent],
            now: Date(timeIntervalSince1970: 1_030),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(stillVisible.sessions.first?.phase, .failed)

        let reExpired = SessionResolver.resolve(
            events: [newEvent],
            now: Date(timeIntervalSince1970: 1_032),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(reExpired.sessions.isEmpty)
    }

    func testNewerDeadPayloadWithOlderTimestampGetsFreshFailedWindow() {
        let oldEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        let newEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 900)
        var memory = ResolutionMemory()

        _ = SessionResolver.resolve(
            events: [oldEvent],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )

        let resolved = SessionResolver.resolve(
            events: [newEvent],
            now: Date(timeIntervalSince1970: 1_016),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )

        XCTAssertEqual(resolved.sessions.first?.phase, .failed)
    }

    func testAbsentEventRemovesDisconnectedMemory() {
        let deadEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        var memory = ResolutionMemory()

        _ = SessionResolver.resolve(
            events: [deadEvent],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertFalse(memory.disconnectedRecords.isEmpty)

        _ = SessionResolver.resolve(
            events: [],
            now: Date(timeIntervalSince1970: 1_001),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )

        XCTAssertTrue(memory.disconnectedRecords.isEmpty)
    }

    func testRetentionExpiredEventRemovesDisconnectedMemory() {
        let deadEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        var memory = ResolutionMemory()

        _ = SessionResolver.resolve(
            events: [deadEvent],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertFalse(memory.disconnectedRecords.isEmpty)

        _ = SessionResolver.resolve(
            events: [deadEvent],
            now: Date(timeIntervalSince1970: 100 + SessionResolver.fileRetention + 1),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )

        XCTAssertTrue(memory.disconnectedRecords.isEmpty)
    }

    func testActiveProvidersEmptyWhenNothingWorking() {
        let resolved = resolve(
            event(provider: .codex, session: "done", phase: .completed, updated: 999)
        )
        XCTAssertEqual(resolved.activeProviders, [])
    }

    func testActiveProvidersExcludesPermission() {
        let resolved = resolve(
            event(provider: .claude, session: "perm", phase: .permission, updated: 999),
            event(provider: .codex, session: "idle", phase: .idle, updated: 999)
        )
        XCTAssertEqual(resolved.activeProviders, [])
    }

    func testActiveProvidersClaudeOnly() {
        let resolved = resolve(
            event(provider: .claude, session: "work", phase: .thinking, updated: 999),
            event(provider: .codex, session: "done", phase: .completed, updated: 999)
        )
        XCTAssertEqual(resolved.activeProviders, [.claude])
    }

    func testActiveProvidersCodexOnly() {
        let resolved = resolve(
            event(provider: .codex, session: "work", phase: .usingTool, updated: 999),
            event(provider: .claude, session: "idle", phase: .idle, updated: 999)
        )
        XCTAssertEqual(resolved.activeProviders, [.codex])
    }

    func testActiveProvidersBothWhenClaudeAndCodexWork() {
        let resolved = resolve(
            event(provider: .claude, session: "think", phase: .thinking, updated: 999),
            event(provider: .codex, session: "tool", phase: .usingTool, updated: 999)
        )
        XCTAssertEqual(resolved.activeProviders, [.claude, .codex])
    }

    func testStuckThinkingWithLiveProcessBecomesIdleAfterStaleActiveDuration() {
        let event = event(provider: .codex, session: "stuck", phase: .thinking, updated: 100)
        var memory = ResolutionMemory()

        let stillThinking = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 100 + SessionResolver.staleActiveDuration - 1),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(stillThinking.sessions.first?.phase, .thinking)

        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 100 + SessionResolver.staleActiveDuration + 1),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .idle)
        XCTAssertEqual(resolved.sessions.first?.label, "Idle")
    }

    func testStuckUsingToolWithLiveProcessBecomesIdleAfterStaleActiveDuration() {
        let event = event(provider: .codex, session: "stuck-tool", phase: .usingTool, updated: 100)
        var memory = ResolutionMemory()

        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 100 + SessionResolver.staleActiveDuration + 1),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .idle)
    }

    func testPendingPermissionWithLiveProcessNeverGoesStale() {
        let event = event(provider: .codex, session: "waiting", phase: .permission, updated: 100)
        var memory = ResolutionMemory()

        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 100 + SessionResolver.staleActiveDuration + 3_600),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .permission)
    }

    func testHiddenSessionIsExcludedFromResolvedSessions() {
        let ev = event(provider: .codex, session: "stale", phase: .permission, updated: 100)
        var memory = ResolutionMemory()
        memory.hide(
            SessionKey(provider: .codex, sessionID: "stale"),
            eventUpdatedAt: Date(timeIntervalSince1970: 100)
        )

        let resolved = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 105),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )

        XCTAssertTrue(resolved.sessions.isEmpty)
    }

    func testHiddenSessionReappearsWhenNewerEventArrives() {
        let key = SessionKey(provider: .codex, sessionID: "stale")
        var memory = ResolutionMemory()
        memory.hide(key, eventUpdatedAt: Date(timeIntervalSince1970: 100))

        let newerEvent = event(provider: .codex, session: "stale", phase: .thinking, updated: 200)
        let resolved = SessionResolver.resolve(
            events: [newerEvent],
            now: Date(timeIntervalSince1970: 205),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )

        XCTAssertEqual(resolved.sessions.first?.sessionID, "stale")
        XCTAssertEqual(resolved.sessions.first?.phase, .thinking)
    }

    func testHiddenRecordPrunedWhenKeyExpiresFromRetention() {
        let key = SessionKey(provider: .codex, sessionID: "stale")
        var memory = ResolutionMemory()
        memory.hide(key, eventUpdatedAt: Date(timeIntervalSince1970: 100))
        let ev = event(provider: .codex, session: "stale", phase: .permission, updated: 100)

        _ = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 100 + SessionResolver.fileRetention + 1),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )

        XCTAssertTrue(memory.hiddenRecords.isEmpty)
    }

    func testHiddenFailedSessionStaysExcludedAndRevealsOnNewerEvent() {
        let deadEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        var memory = ResolutionMemory()

        let disconnected = SessionResolver.resolve(
            events: [deadEvent],
            now: Date(timeIntervalSince1970: 100),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(disconnected.sessions.first?.phase, .failed)

        memory.hide(
            SessionKey(provider: .claude, sessionID: "dead"),
            eventUpdatedAt: Date(timeIntervalSince1970: 100)
        )

        let hidden = SessionResolver.resolve(
            events: [deadEvent],
            now: Date(timeIntervalSince1970: 105),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(hidden.sessions.isEmpty)

        let newerEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 200)
        let revealed = SessionResolver.resolve(
            events: [newerEvent],
            now: Date(timeIntervalSince1970: 205),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(revealed.sessions.first?.sessionID, "dead")
        XCTAssertEqual(revealed.sessions.first?.phase, .thinking)
    }

    func testResolvedSnapshotCarriesToolCategoryFromEvent() {
        let resolved = resolve(
            event(provider: .codex, session: "editing", phase: .usingTool, updated: 999)
        )
        XCTAssertEqual(resolved.sessions.first?.toolCategory, .edit)
    }

    func testResolvedSnapshotHasNoToolCategoryWhileThinking() {
        let resolved = resolve(
            event(provider: .codex, session: "thinking", phase: .thinking, updated: 999)
        )
        XCTAssertNil(resolved.sessions.first?.toolCategory)
    }

    func testUnknownProcessExpiresAfterFourHours() {
        var event = event(provider: .codex, session: "old", phase: .thinking, updated: 100)
        event = NormalizedEvent(
            schemaVersion: event.schemaVersion,
            provider: event.provider,
            surface: event.surface,
            sessionID: event.sessionID,
            turnID: event.turnID,
            phase: event.phase,
            label: event.label,
            toolCategory: event.toolCategory,
            projectName: event.projectName,
            workingDirectory: event.workingDirectory,
            sourceBundleID: event.sourceBundleID,
            sourceProcessID: nil,
            sourceProcessStartedAt: nil,
            turnStartedAt: event.turnStartedAt,
            updatedAt: event.updatedAt
        )
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 100 + 14_401),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertTrue(resolved.sessions.isEmpty)
    }
}

private func resolve(_ events: NormalizedEvent...) -> ResolvedSessions {
    var memory = ResolutionMemory()
    return SessionResolver.resolve(
        events: events,
        now: Date(timeIntervalSince1970: 1_000),
        memory: &memory,
        isProcessAlive: { _, _ in true }
    )
}

private func event(
    provider: AgentProvider,
    session: String,
    phase: SessionPhase,
    updated: TimeInterval
) -> NormalizedEvent {
    NormalizedEvent(
        schemaVersion: 1,
        provider: provider,
        surface: .cli,
        sessionID: session,
        turnID: "turn-\(session)",
        phase: phase,
        label: phase == .permission ? "Awaiting permission" : phase.rawValue,
        toolCategory: phase == .usingTool ? .edit : nil,
        projectName: session.capitalized,
        workingDirectory: "/tmp/\(session)",
        sourceBundleID: "com.apple.Terminal",
        sourceProcessID: 42,
        sourceProcessStartedAt: Date(timeIntervalSince1970: 50),
        turnStartedAt: Date(timeIntervalSince1970: 90),
        updatedAt: Date(timeIntervalSince1970: updated)
    )
}

/// Like `event(...)` but with a distinct `sourceProcessID`, so a test's
/// `isProcessAlive` closure can report this one session's process as dead
/// while other sessions in the same `resolve` call stay alive.
private func deadPidEvent(
    pid: Int32,
    provider: AgentProvider,
    session: String,
    phase: SessionPhase,
    updated: TimeInterval
) -> NormalizedEvent {
    var base = event(provider: provider, session: session, phase: phase, updated: updated)
    base = NormalizedEvent(
        schemaVersion: base.schemaVersion,
        provider: base.provider,
        surface: base.surface,
        sessionID: base.sessionID,
        turnID: base.turnID,
        phase: base.phase,
        label: base.label,
        toolCategory: base.toolCategory,
        projectName: base.projectName,
        workingDirectory: base.workingDirectory,
        sourceBundleID: base.sourceBundleID,
        sourceProcessID: pid,
        sourceProcessStartedAt: base.sourceProcessStartedAt,
        turnStartedAt: base.turnStartedAt,
        updatedAt: base.updatedAt
    )
    return base
}
