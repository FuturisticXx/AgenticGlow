import Foundation

/// Converts the app's live state into a WidgetSnapshot. Pure and
/// side-effect free so it is fully unit testable. AppModel calls this and
/// writes the result to the App Group container without adding data-layer
/// logic in the app target.
public enum WidgetSnapshotBuilder {
    /// Sessions beyond this count are dropped from the snapshot entirely.
    /// Kept above what any single family displays (large shows at most 4
    /// at a time, see LargeWidgetView) so a future family or a
    /// configuration option showing more rows doesn't need a data-layer
    /// change, just a display-layer one.
    public static let maximumSessions = 8

    private static let attentionPhases: Set<SessionPhase> = [.permission, .failed]

    public static func build(
        resolved: ResolvedSessions,
        allowances: [AgentProvider: ProviderAllowance],
        installedProviders: [AgentProvider: Bool],
        now: Date
    ) -> WidgetSnapshot {
        // resolved.sessions is already sorted by SessionResolver's own
        // priority order (permission > usingTool > thinking > failed >
        // completed > disconnected > idle); reuse that order as-is rather
        // than re-deriving it here.
        let sessions = resolved.sessions.prefix(maximumSessions).map { snapshot in
            WidgetSessionSummary(
                provider: snapshot.provider,
                sessionID: snapshot.sessionID,
                projectName: snapshot.projectName,
                phase: snapshot.phase,
                toolCategory: snapshot.toolCategory,
                elapsedSeconds: snapshot.elapsedSeconds,
                updatedAt: snapshot.updatedAt,
                needsAttention: attentionPhases.contains(snapshot.phase)
            )
        }

        let allowanceSummaries = AgentProvider.allCases.compactMap { provider -> WidgetAllowanceSummary? in
            guard let allowance = allowances[provider] else { return nil }
            return WidgetAllowanceSummary(
                provider: provider,
                currentWindowLabel: allowance.currentWindowLabel,
                currentPercentLeft: allowance.currentPercentLeft,
                currentResetAt: allowance.currentResetAt,
                weeklyPercentLeft: allowance.weeklyPercentLeft,
                weeklyResetAt: allowance.weeklyResetAt,
                fetchedAt: allowance.fetchedAt
            )
        }

        let providerSummaries = AgentProvider.allCases.map { provider in
            WidgetProviderSummary(provider: provider, installed: installedProviders[provider] ?? false)
        }

        return WidgetSnapshot(
            generatedAt: now,
            sessions: Array(sessions),
            allowances: allowanceSummaries,
            providers: providerSummaries,
            attentionCount: resolved.sessions.filter { attentionPhases.contains($0.phase) }.count,
            activeCount: resolved.activeCount
        )
    }

    /// Whether a fresh snapshot is worth writing and reloading the widget
    /// for. Deliberately ignores fields that change on every tick for an
    /// active session (`elapsedSeconds`, `updatedAt`, `fetchedAt`,
    /// `generatedAt`) so a reload isn't triggered every 2s while something
    /// is thinking; those values still get refreshed as a side effect of
    /// any other meaningful change.
    public static func isMeaningfullyDifferent(_ lhs: WidgetSnapshot, from rhs: WidgetSnapshot) -> Bool {
        lhs.schemaVersion != rhs.schemaVersion
            || lhs.attentionCount != rhs.attentionCount
            || lhs.activeCount != rhs.activeCount
            || lhs.providers != rhs.providers
            || !sessionsMatch(lhs.sessions, rhs.sessions)
            || !allowancesMatch(lhs.allowances, rhs.allowances)
    }

    private static func sessionsMatch(_ lhs: [WidgetSessionSummary], _ rhs: [WidgetSessionSummary]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { a, b in
            a.provider == b.provider
                && a.sessionID == b.sessionID
                && a.projectName == b.projectName
                && a.phase == b.phase
                && a.toolCategory == b.toolCategory
                && a.needsAttention == b.needsAttention
        }
    }

    private static func allowancesMatch(_ lhs: [WidgetAllowanceSummary], _ rhs: [WidgetAllowanceSummary]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { a, b in
            a.provider == b.provider
                && a.currentWindowLabel == b.currentWindowLabel
                && a.currentPercentLeft == b.currentPercentLeft
                && a.currentResetAt == b.currentResetAt
                && a.weeklyPercentLeft == b.weeklyPercentLeft
                && a.weeklyResetAt == b.weeklyResetAt
        }
    }
}
