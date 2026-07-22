import Foundation
import AgenticGlowCore

/// Illustrative fixtures used only for the WidgetKit gallery preview
/// (shown before a user adds the widget) and SwiftUI #Preview canvases.
/// Never used as a fallback for real data; AppGroupSnapshotSource's honest
/// states (.notConfigured / .noSnapshotYet / .corrupted) are what actually
/// ships when there is nothing real to show.
enum SampleData {
    static let now = Date()

    static let workingSession = WidgetSessionSummary(
        provider: .claude, sessionID: "sample-1", projectName: "AgenticGlow",
        phase: .thinking, toolCategory: nil, elapsedSeconds: 125, updatedAt: now, needsAttention: false
    )

    static let editingSession = WidgetSessionSummary(
        provider: .claude, sessionID: "sample-2", projectName: "Horizon",
        phase: .usingTool, toolCategory: .edit, elapsedSeconds: 305, updatedAt: now, needsAttention: false
    )

    static let attentionSession = WidgetSessionSummary(
        provider: .codex, sessionID: "sample-3", projectName: "Marketing Site",
        phase: .permission, toolCategory: nil, elapsedSeconds: 40, updatedAt: now, needsAttention: true
    )

    static let failedSession = WidgetSessionSummary(
        provider: .codex, sessionID: "sample-4", projectName: "Data Pipeline",
        phase: .failed, toolCategory: nil, elapsedSeconds: nil, updatedAt: now.addingTimeInterval(-600),
        needsAttention: true
    )

    static let claudeAllowance = WidgetAllowanceSummary(
        provider: .claude, currentWindowLabel: "5h", currentPercentLeft: 62,
        currentResetAt: now.addingTimeInterval(2 * 3600 + 15 * 60),
        weeklyPercentLeft: 38, weeklyResetAt: now.addingTimeInterval(4 * 86_400), fetchedAt: now
    )

    static let codexAllowanceLow = WidgetAllowanceSummary(
        provider: .codex, currentWindowLabel: "5h", currentPercentLeft: 6,
        currentResetAt: now.addingTimeInterval(45 * 60),
        weeklyPercentLeft: 12, weeklyResetAt: now.addingTimeInterval(2 * 86_400), fetchedAt: now
    )

    static let bothProvidersInstalled = [
        WidgetProviderSummary(provider: .claude, installed: true),
        WidgetProviderSummary(provider: .codex, installed: true)
    ]

    static let onlyClaudeInstalled = [
        WidgetProviderSummary(provider: .claude, installed: true),
        WidgetProviderSummary(provider: .codex, installed: false)
    ]

    static let busySnapshot = WidgetSnapshot(
        generatedAt: now,
        sessions: [attentionSession, editingSession, workingSession],
        allowances: [claudeAllowance, codexAllowanceLow],
        providers: bothProvidersInstalled,
        attentionCount: 1,
        activeCount: 2
    )

    static let attentionOnlySnapshot = WidgetSnapshot(
        generatedAt: now,
        sessions: [attentionSession],
        allowances: [claudeAllowance],
        providers: bothProvidersInstalled,
        attentionCount: 1,
        activeCount: 0
    )

    static let failedSnapshot = WidgetSnapshot(
        generatedAt: now,
        sessions: [failedSession],
        allowances: [],
        providers: bothProvidersInstalled,
        attentionCount: 1,
        activeCount: 0
    )

    static let lowAllowanceSnapshot = WidgetSnapshot(
        generatedAt: now,
        sessions: [],
        allowances: [codexAllowanceLow],
        providers: bothProvidersInstalled,
        attentionCount: 0,
        activeCount: 0
    )

    /// Also demonstrates the "provider not set up" notice (Codex not
    /// installed) alongside a calm, idle Claude-only state.
    static let idleSnapshot = WidgetSnapshot(
        generatedAt: now,
        sessions: [],
        allowances: [claudeAllowance],
        providers: onlyClaudeInstalled,
        attentionCount: 0,
        activeCount: 0
    )

    static let staleSnapshot = WidgetSnapshot(
        generatedAt: now.addingTimeInterval(-40 * 60),
        sessions: [workingSession],
        allowances: [claudeAllowance],
        providers: onlyClaudeInstalled,
        attentionCount: 0,
        activeCount: 1
    )
}
