import Foundation
import XCTest
@testable import AgenticGlowCore

final class WidgetSnapshotBuilderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testEmptyResolvedSessionsProducesEmptySnapshot() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []),
            allowances: [:],
            installedProviders: [:],
            now: now
        )
        XCTAssertTrue(snapshot.sessions.isEmpty)
        XCTAssertTrue(snapshot.allowances.isEmpty)
        XCTAssertEqual(snapshot.attentionCount, 0)
        XCTAssertEqual(snapshot.activeCount, 0)
        XCTAssertEqual(snapshot.providers, [
            WidgetProviderSummary(provider: .codex, installed: false),
            WidgetProviderSummary(provider: .claude, installed: false),
            WidgetProviderSummary(provider: .cursor, installed: false)
        ])
    }

    func testPreservesResolvedSessionOrder() {
        // SessionResolver already sorts by priority; the builder must not
        // re-sort or change that order.
        let permission = session(id: "p", phase: .permission)
        let thinking = session(id: "t", phase: .thinking)
        let idle = session(id: "i", phase: .idle)
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [permission, thinking, idle]),
            allowances: [:],
            installedProviders: [:],
            now: now
        )
        XCTAssertEqual(snapshot.sessions.map(\.sessionID), ["p", "t", "i"])
    }

    func testCapsSessionsAtMaximum() {
        let sessions = (0..<20).map { session(id: "s\($0)", phase: .idle) }
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: sessions),
            allowances: [:],
            installedProviders: [:],
            now: now
        )
        XCTAssertEqual(snapshot.sessions.count, WidgetSnapshotBuilder.maximumSessions)
    }

    func testAttentionCountCountsFullSetNotOnlyCappedSessions() {
        // 10 permission sessions but the snapshot only carries 8 rows;
        // attentionCount must still reflect all 10.
        let sessions = (0..<10).map { session(id: "s\($0)", phase: .permission) }
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: sessions),
            allowances: [:],
            installedProviders: [:],
            now: now
        )
        XCTAssertEqual(snapshot.sessions.count, WidgetSnapshotBuilder.maximumSessions)
        XCTAssertEqual(snapshot.attentionCount, 10)
    }

    func testFailedPhaseCountsAsAttention() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "f", phase: .failed)]),
            allowances: [:],
            installedProviders: [:],
            now: now
        )
        XCTAssertEqual(snapshot.attentionCount, 1)
        XCTAssertTrue(snapshot.sessions[0].needsAttention)
    }

    func testWorkingPhasesDoNotCountAsAttention() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "t", phase: .thinking)]),
            allowances: [:],
            installedProviders: [:],
            now: now
        )
        XCTAssertEqual(snapshot.attentionCount, 0)
        XCTAssertFalse(snapshot.sessions[0].needsAttention)
    }

    func testMultipleProvidersIncludedIndependently() {
        let allowances: [AgentProvider: ProviderAllowance] = [
            .claude: allowance(provider: .claude, currentPercentUsed: 20),
            .codex: allowance(provider: .codex, currentPercentUsed: 80)
        ]
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []),
            allowances: allowances,
            installedProviders: [.claude: true, .codex: false],
            now: now
        )
        XCTAssertEqual(Set(snapshot.allowances.map(\.provider)), [.claude, .codex])
        XCTAssertEqual(snapshot.providers.first { $0.provider == .claude }?.installed, true)
        XCTAssertEqual(snapshot.providers.first { $0.provider == .codex }?.installed, false)
    }

    func testMissingAllowanceIsOmittedNotFabricated() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []),
            allowances: [.claude: allowance(provider: .claude, currentPercentUsed: 20)],
            installedProviders: [:],
            now: now
        )
        XCTAssertEqual(snapshot.allowances.map(\.provider), [.claude])
    }

    func testActiveCountPassesThroughFromResolvedSessions() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [], activeCount: 3),
            allowances: [:],
            installedProviders: [:],
            now: now
        )
        XCTAssertEqual(snapshot.activeCount, 3)
    }

    // MARK: - isMeaningfullyDifferent

    func testIdenticalSnapshotsAreNotMeaningfullyDifferent() {
        let a = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .thinking)]),
            allowances: [:], installedProviders: [:], now: now
        )
        let b = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .thinking)]),
            allowances: [:], installedProviders: [:], now: now.addingTimeInterval(2)
        )
        XCTAssertFalse(WidgetSnapshotBuilder.isMeaningfullyDifferent(b, from: a))
    }

    func testElapsedSecondsChangeAloneIsNotMeaningfullyDifferent() {
        let a = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .thinking, elapsedSeconds: 10)]),
            allowances: [:], installedProviders: [:], now: now
        )
        let b = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .thinking, elapsedSeconds: 130)]),
            allowances: [:], installedProviders: [:], now: now.addingTimeInterval(120)
        )
        XCTAssertFalse(WidgetSnapshotBuilder.isMeaningfullyDifferent(b, from: a))
    }

    func testAllowanceFetchedAtChangeAloneIsNotMeaningfullyDifferent() {
        let a = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []),
            allowances: [.claude: allowance(provider: .claude, currentPercentUsed: 20)],
            installedProviders: [:], now: now
        )
        let b = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []),
            allowances: [.claude: allowance(provider: .claude, currentPercentUsed: 20)],
            installedProviders: [:], now: now.addingTimeInterval(60)
        )
        XCTAssertFalse(WidgetSnapshotBuilder.isMeaningfullyDifferent(b, from: a))
    }

    func testPhaseChangeIsMeaningfullyDifferent() {
        let a = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .thinking)]),
            allowances: [:], installedProviders: [:], now: now
        )
        let b = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .permission)]),
            allowances: [:], installedProviders: [:], now: now
        )
        XCTAssertTrue(WidgetSnapshotBuilder.isMeaningfullyDifferent(b, from: a))
    }

    func testSessionCountChangeIsMeaningfullyDifferent() {
        let a = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .thinking)]),
            allowances: [:], installedProviders: [:], now: now
        )
        let b = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .thinking), session(id: "t", phase: .idle)]),
            allowances: [:], installedProviders: [:], now: now
        )
        XCTAssertTrue(WidgetSnapshotBuilder.isMeaningfullyDifferent(b, from: a))
    }

    func testAllowancePercentChangeIsMeaningfullyDifferent() {
        let a = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []),
            allowances: [.claude: allowance(provider: .claude, currentPercentUsed: 20)],
            installedProviders: [:], now: now
        )
        let b = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []),
            allowances: [.claude: allowance(provider: .claude, currentPercentUsed: 25)],
            installedProviders: [:], now: now
        )
        XCTAssertTrue(WidgetSnapshotBuilder.isMeaningfullyDifferent(b, from: a))
    }

    func testSingleSessionWorkLeavesCompactDetailNil() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [session(id: "s", phase: .thinking, path: "/tmp/AgenticGlow")], activeCount: 1),
            allowances: [:], installedProviders: [:], now: now
        )
        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertNil(snapshot.sessions[0].compactDetail)
        XCTAssertEqual(snapshot.sessions[0].projectName, "AgenticGlow")
        XCTAssertEqual(WidgetSmallCopy.title(for: snapshot), "1 session")
        XCTAssertEqual(WidgetSmallCopy.subtitle(for: snapshot), "active")
    }

    func testSameFolderCompressesToOneRow() {
        let sessions = [
            session(id: "g", provider: .cursor, phase: .thinking, path: "/tmp/AgenticGlow", model: "grok-4.6"),
            session(id: "c", provider: .cursor, phase: .thinking, path: "/tmp/AgenticGlow", model: "claude-sonnet-5-thinking-high"),
            session(id: "p", provider: .cursor, phase: .thinking, path: "/tmp/AgenticGlow", model: "composer-2.5-fast")
        ]
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: sessions, activeCount: 3),
            allowances: [:], installedProviders: [:], now: now
        )
        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertEqual(snapshot.sessions[0].projectName, "AgenticGlow")
        XCTAssertEqual(snapshot.sessions[0].compactDetail, "3 active · Claude, Grok, Composer")
        XCTAssertEqual(snapshot.attentionCount, 0)
        XCTAssertEqual(snapshot.activeCount, 3)
        XCTAssertEqual(WidgetSmallCopy.title(for: snapshot), "AgenticGlow")
        XCTAssertEqual(WidgetSmallCopy.subtitle(for: snapshot), "3 active")
    }

    func testDifferentFoldersStaySeparateRows() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [
                session(id: "a", phase: .thinking, path: "/tmp/AgenticGlow"),
                session(id: "b", phase: .thinking, path: "/tmp/Moodpaper")
            ], activeCount: 2),
            allowances: [:], installedProviders: [:], now: now
        )
        XCTAssertEqual(snapshot.sessions.map(\.projectName), ["AgenticGlow", "Moodpaper"])
        XCTAssertTrue(snapshot.sessions.allSatisfy { $0.compactDetail == nil })
        XCTAssertEqual(WidgetSmallCopy.title(for: snapshot), "2 sessions")
        XCTAssertEqual(WidgetSmallCopy.subtitle(for: snapshot), "active")
    }

    func testWorktreeSlugBecomesHumanTitleOnWidgetRow() {
        let path = "/Volumes/Liquid/2DaMax Development/Caliber Wallet/.claude/worktrees/goal-5-5c-execution-04a6d8"
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [
                session(id: "tree", phase: .usingTool, path: path)
            ], activeCount: 1),
            allowances: [:], installedProviders: [:], now: now
        )
        XCTAssertEqual(snapshot.sessions[0].projectName, "Goal 5 5c Execution")
        XCTAssertEqual(snapshot.sessions[0].sessionID, "tree")
    }

    func testDuplicateAdapterReportsCompressToOneCursorRow() {
        let sid = "sid_dd1e00780b983db555e9b4a776bc48b98ca13eafb30b5dee3c79e004117e541c"
        let claude = SessionSnapshot(
            provider: .claude,
            surface: .desktop,
            sessionID: sid,
            phase: .thinking,
            label: "Thinking",
            projectName: "AgenticGlow",
            workingDirectory: "/tmp/AgenticGlow",
            sourceBundleID: nil,
            elapsedSeconds: 12,
            updatedAt: now,
            model: "grok-4.6"
        )
        let cursor = SessionSnapshot(
            provider: .cursor,
            surface: .desktop,
            sessionID: sid,
            phase: .usingTool,
            label: "Reading",
            projectName: "AgenticGlow",
            workingDirectory: "/tmp/AgenticGlow",
            sourceBundleID: AgentProvider.cursorBundleIdentifier,
            elapsedSeconds: 12,
            updatedAt: now,
            toolCategory: .read,
            model: "grok-4.6"
        )
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [claude, cursor], activeCount: 2),
            allowances: [:],
            installedProviders: [:],
            now: now
        )
        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertEqual(snapshot.sessions[0].provider, .cursor)
        XCTAssertEqual(snapshot.sessions[0].sessionID, sid)
        XCTAssertNil(snapshot.sessions[0].compactDetail)
        XCTAssertEqual(snapshot.sessions[0].phase, .usingTool)
    }

    func testAttentionCountStillCountsSessionsNotGroups() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: [
                session(id: "a", phase: .permission, path: "/tmp/AgenticGlow"),
                session(id: "b", phase: .permission, path: "/tmp/AgenticGlow")
            ]),
            allowances: [:], installedProviders: [:], now: now
        )
        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertEqual(snapshot.attentionCount, 2)
        XCTAssertEqual(WidgetSmallCopy.title(for: snapshot), "AgenticGlow")
        XCTAssertEqual(WidgetSmallCopy.subtitle(for: snapshot), "needs you")
    }

    func testInstalledProviderChangeIsMeaningfullyDifferent() {
        let a = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []), allowances: [:],
            installedProviders: [.claude: false], now: now
        )
        let b = WidgetSnapshotBuilder.build(
            resolved: resolved(sessions: []), allowances: [:],
            installedProviders: [.claude: true], now: now
        )
        XCTAssertTrue(WidgetSnapshotBuilder.isMeaningfullyDifferent(b, from: a))
    }

    // MARK: - Fixtures

    private func resolved(
        sessions: [SessionSnapshot],
        activeCount: Int = 0
    ) -> ResolvedSessions {
        ResolvedSessions(
            sessions: sessions,
            dominantPhase: sessions.first?.phase ?? .idle,
            activeCount: activeCount,
            permissionCount: sessions.filter { $0.phase == .permission }.count,
            activeProviders: []
        )
    }

    private func session(
        id: String,
        provider: AgentProvider = .claude,
        phase: SessionPhase,
        elapsedSeconds: Int = 12,
        path: String = "",
        model: String? = nil
    ) -> SessionSnapshot {
        SessionSnapshot(
            provider: provider,
            surface: .cli,
            sessionID: id,
            phase: phase,
            label: "Working",
            projectName: path.isEmpty ? "AgenticGlow" : URL(fileURLWithPath: path).lastPathComponent,
            workingDirectory: path,
            sourceBundleID: nil,
            elapsedSeconds: elapsedSeconds,
            updatedAt: now,
            toolCategory: nil,
            model: model
        )
    }

    private func allowance(provider: AgentProvider, currentPercentUsed: Double) -> ProviderAllowance {
        ProviderAllowance(
            provider: provider,
            currentWindowLabel: "5h",
            currentPercentUsed: currentPercentUsed,
            currentResetAt: now.addingTimeInterval(3600),
            weeklyPercentUsed: currentPercentUsed,
            weeklyResetAt: now.addingTimeInterval(86_400),
            fetchedAt: now
        )
    }
}
