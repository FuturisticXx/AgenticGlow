import XCTest
@testable import KlarityCore

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

    func testDeadProcessBecomesDisconnected() {
        let event = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .disconnected)

        let expired = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_016),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(expired.sessions.isEmpty)
    }

    func testNewDeadEventWithSameKeyGetsFreshDisconnectedWindowAfterOlderEventExpires() {
        let oldEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        let newEvent = event(provider: .claude, session: "dead", phase: .thinking, updated: 1_005)
        var memory = ResolutionMemory()

        let initial = SessionResolver.resolve(
            events: [oldEvent],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(initial.sessions.first?.phase, .disconnected)

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
        XCTAssertEqual(refreshed.sessions.first?.phase, .disconnected)

        let stillVisible = SessionResolver.resolve(
            events: [newEvent],
            now: Date(timeIntervalSince1970: 1_030),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(stillVisible.sessions.first?.phase, .disconnected)

        let reExpired = SessionResolver.resolve(
            events: [newEvent],
            now: Date(timeIntervalSince1970: 1_032),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(reExpired.sessions.isEmpty)
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
