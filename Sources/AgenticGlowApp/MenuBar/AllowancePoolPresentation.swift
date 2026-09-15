import Foundation
import AgenticGlowCore

/// Popover copy for a provider that reports named sub-pools instead of
/// time windows. Deliberately mirrors `AllowancePresentation`'s wording
/// and thresholds so a Cursor row reads like a Codex or Claude row: same
/// percentage phrasing, same low-allowance rule, same reset formatting
/// shared with the widget through `WidgetSnapshotFormatting`.
struct AllowancePoolPresentation {
    struct Pool {
        let id: String
        let label: String
        let leftPercent: String?
        let progress: Double
        let isLow: Bool
        /// Set only when the pools reset at different times. A shared
        /// reset is stated once for the provider instead.
        let resetValue: String?
        let accessibility: String
    }

    let pools: [Pool]
    /// Set only when every pool resets at the same moment, which is the
    /// normal Cursor case: both lanes are metered against one billing
    /// cycle. Shown once under the bars instead of repeated per pool.
    let sharedResetValue: String?

    init(allowance: ProviderAllowance, now: Date) {
        let provider = allowance.provider
        let sharedReset = Self.sharedReset(in: allowance.pools)
        sharedResetValue = sharedReset.map { Self.reset($0, now: now) }
        pools = allowance.pools.map { pool in
            let isLow = (pool.percentLeft ?? .infinity) < AllowanceWarning.thresholdPercentLeft
            return Pool(
                id: pool.id,
                label: pool.label,
                leftPercent: pool.percentLeft.map { String(Int($0.rounded())) },
                progress: (pool.percentLeft ?? 0) / 100,
                isLow: isLow,
                resetValue: sharedReset == nil
                    ? pool.resetAt.map { Self.reset($0, now: now) }
                    : nil,
                accessibility: Self.spoken(
                    provider: provider,
                    pool: pool,
                    isLow: isLow,
                    now: now
                )
            )
        }
    }

    private static func sharedReset(in pools: [AllowancePool]) -> Date? {
        let resets = pools.compactMap(\.resetAt)
        guard resets.count == pools.count, let first = resets.first else { return nil }
        return resets.allSatisfy { $0 == first } ? first : nil
    }

    static func reset(_ date: Date, now: Date) -> String {
        let absolute = WidgetSnapshotFormatting.absoluteResetLabel(date, now: now) ?? ""
        guard
            WidgetSnapshotFormatting.showsCountdown(date, now: now),
            let relative = WidgetSnapshotFormatting.relativeResetLabel(date, now: now)
        else { return absolute }
        return "\(relative) (\(absolute))"
    }

    private static func spoken(
        provider: AgentProvider,
        pool: AllowancePool,
        isLow: Bool,
        now: Date
    ) -> String {
        var parts = [provider.displayName, pool.label]
        if let left = pool.percentLeft {
            parts.append("\(Int(left.rounded())) percent left")
        } else {
            parts.append("unavailable")
        }
        if let resetAt = pool.resetAt {
            parts.append("resets \(resetAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if isLow { parts.append("low") }
        return parts.joined(separator: ", ")
    }
}
