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
        now: Date,
        revision: Int = 0
    ) -> WidgetSnapshot {
        // Group by work identity, then keep SessionResolver's attention
        // order via WorkGrouping. One row per work; the snapshot cap is
        // unchanged. attentionCount still counts sessions, not groups.
        let sessions = WorkGrouping.groups(from: resolved.sessions)
            .prefix(maximumSessions)
            .map { group in
                let snapshot = group.representative
                return WidgetSessionSummary(
                    provider: snapshot.provider,
                    sessionID: snapshot.sessionID,
                    projectName: group.presentation.displayName,
                    phase: snapshot.phase,
                    toolCategory: snapshot.toolCategory,
                    elapsedSeconds: snapshot.elapsedSeconds,
                    updatedAt: snapshot.updatedAt,
                    needsAttention: attentionPhases.contains(snapshot.phase),
                    compactDetail: group.sessions.count > 1 ? WorkStatusLine.compact(for: group) : nil
                )
            }

        let allowanceSummaries = AgentProvider.allCases.compactMap { provider -> WidgetAllowanceSummary? in
            guard let allowance = allowances[provider] else { return nil }
            return WidgetAllowanceSummary(
                provider: provider,
                currentWindowLabel: allowance.currentWindowLabel,
                currentWindowDuration: allowance.currentWindowDuration,
                currentPercentLeft: allowance.currentPercentLeft,
                currentResetAt: allowance.currentResetAt,
                weeklyPercentLeft: allowance.weeklyPercentLeft,
                weeklyResetAt: allowance.weeklyResetAt,
                pools: allowance.pools.map { pool in
                    WidgetAllowancePool(
                        id: pool.id,
                        label: pool.label,
                        percentLeft: pool.percentLeft,
                        resetAt: pool.resetAt
                    )
                },
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
            activeCount: resolved.activeCount,
            revision: revision
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

    /// Whether `lhs` carries a newer observation of some provider's
    /// allowance than `rhs` does. `isMeaningfullyDifferent` ignores
    /// `fetchedAt`, so without this a provider re-read with unchanged
    /// values never reached the widget, which then judged those values
    /// by the old read's age.
    public static func allowanceObservationsAdvanced(_ lhs: WidgetSnapshot, from rhs: WidgetSnapshot) -> Bool {
        lhs.allowances.contains { allowance in
            guard let previous = rhs.allowances.first(where: { $0.provider == allowance.provider }) else {
                return true
            }
            return allowance.fetchedAt > previous.fetchedAt
        }
    }

    /// Whether a provider the widget would label stale from `rhs` reads
    /// as current in `lhs`. The one re-observation worth a reload: it
    /// removes a label already on the canvas, and it happens once per
    /// recovery rather than on every refresh.
    public static func clearsStaleAllowance(_ lhs: WidgetSnapshot, from rhs: WidgetSnapshot, now: Date) -> Bool {
        lhs.allowances.contains { allowance in
            guard allowance.staleLabel(now: now) == nil,
                  let previous = rhs.allowances.first(where: { $0.provider == allowance.provider })
            else { return false }
            return previous.staleLabel(now: now) != nil
        }
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
                && a.compactDetail == b.compactDetail
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
                && a.pools == b.pools
        }
    }
}
