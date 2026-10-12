import Foundation

/// The widget-safe view of AgenticGlow's state. Contains only fields already
/// covered by the existing privacy contract (docs/privacy.md): no prompts,
/// no raw provider responses, no credentials. Written by the main app to the
/// App Group shared container and read by the widget extension.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let generatedAt: Date
    public let sessions: [WidgetSessionSummary]
    public let allowances: [WidgetAllowanceSummary]
    public let providers: [WidgetProviderSummary]
    public let attentionCount: Int
    public let activeCount: Int
    /// How many snapshots the app has published this launch.
    ///
    /// Advances by one each time AgenticGlow actually writes a snapshot,
    /// which it already does only when something worth showing changed.
    /// It costs no write of its own: it rides inside the write that was
    /// happening anyway, and nothing reads or stores it outside this file.
    ///
    /// The large widget uses it to give its single session row a different
    /// session each time the widget naturally refreshes, so the row is a
    /// window onto every eligible session rather than being stuck on the
    /// first one. A counter rather than a clock, because the row has to
    /// advance with the data, and because a value derived from the time
    /// would jump around the list instead of walking it in order.
    public let revision: Int

    public init(
        schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
        generatedAt: Date,
        sessions: [WidgetSessionSummary],
        allowances: [WidgetAllowanceSummary],
        providers: [WidgetProviderSummary],
        attentionCount: Int,
        activeCount: Int,
        revision: Int = 0
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.sessions = sessions
        self.allowances = allowances
        self.providers = providers
        self.attentionCount = attentionCount
        self.activeCount = activeCount
        self.revision = revision
    }

    /// The same snapshot under another revision. Used when the app rewrites
    /// a snapshot whose shown data did not change, which must not advance
    /// anything keyed on the revision.
    public func withRevision(_ revision: Int) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: schemaVersion,
            generatedAt: generatedAt,
            sessions: sessions,
            allowances: allowances,
            providers: providers,
            attentionCount: attentionCount,
            activeCount: activeCount,
            revision: revision
        )
    }

    /// Hand-written for the same reason as `WidgetAllowanceSummary`'s: a
    /// snapshot written by an older app build has no `revision` key, and
    /// the widget must render it rather than fail the whole decode and
    /// drop to its "unavailable" state. A missing revision reads as 0,
    /// which shows the first session, exactly as before rotation existed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        sessions = try container.decode([WidgetSessionSummary].self, forKey: .sessions)
        allowances = try container.decode([WidgetAllowanceSummary].self, forKey: .allowances)
        providers = try container.decode([WidgetProviderSummary].self, forKey: .providers)
        attentionCount = try container.decode(Int.self, forKey: .attentionCount)
        activeCount = try container.decode(Int.self, forKey: .activeCount)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
    }

    public static let empty = WidgetSnapshot(
        generatedAt: .distantPast,
        sessions: [],
        allowances: [],
        providers: [],
        attentionCount: 0,
        activeCount: 0
    )

    /// Allowances on the widget's default page: providers that report
    /// time windows. A provider with sub-pools is shown on its own page
    /// instead, so enabling it never costs the overview its breathing
    /// room.
    public var overviewAllowances: [WidgetAllowanceSummary] {
        allowances.filter { $0.pools.isEmpty }
    }

    /// Allowances that have their own page, in snapshot order.
    public var poolAllowances: [WidgetAllowanceSummary] {
        allowances.filter { !$0.pools.isEmpty }
    }

    /// Providers with genuinely no signal: no sessions, no allowance data,
    /// and no hook integration installed. `providers[].installed` alone
    /// isn't enough to call a provider "not set up" — Codex sessions and
    /// allowance can both surface through hook-independent fallbacks (the
    /// read-only session-discovery RPC and the rate-limits RPC), so a
    /// provider whose hooks aren't installed but who still has visible
    /// data isn't missing from the user's point of view.
    public var providersWithoutData: [AgentProvider] {
        let providersWithData = Set(sessions.map(\.provider)).union(allowances.map(\.provider))
        return providers
            .filter { !$0.installed && !providersWithData.contains($0.provider) }
            .map(\.provider)
    }
}

public struct WidgetSessionSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(provider.rawValue):\(sessionID)" }
    public let provider: AgentProvider
    public let sessionID: String
    public let projectName: String
    public let phase: SessionPhase
    public let toolCategory: ToolCategory?
    public let elapsedSeconds: Int?
    public let updatedAt: Date
    public let needsAttention: Bool
    /// Set only for a multi-session work group. Nil keeps today's
    /// phase / phase · provider secondary line.
    public let compactDetail: String?

    public init(
        provider: AgentProvider,
        sessionID: String,
        projectName: String,
        phase: SessionPhase,
        toolCategory: ToolCategory?,
        elapsedSeconds: Int?,
        updatedAt: Date,
        needsAttention: Bool,
        compactDetail: String? = nil
    ) {
        self.provider = provider
        self.sessionID = sessionID
        self.projectName = projectName
        self.phase = phase
        self.toolCategory = toolCategory
        self.elapsedSeconds = elapsedSeconds
        self.updatedAt = updatedAt
        self.needsAttention = needsAttention
        self.compactDetail = compactDetail
    }
}

public struct WidgetAllowanceSummary: Codable, Equatable, Sendable {
    public let provider: AgentProvider
    public let currentWindowLabel: String
    /// The current window's period, carried so a disconnected iPhone can
    /// tell that the window elapsed. See `ProviderAllowance`.
    public let currentWindowDuration: TimeInterval?
    public let currentPercentLeft: Double?
    public let currentResetAt: Date?
    public let weeklyPercentLeft: Double?
    public let weeklyResetAt: Date?
    /// Named sub-pools for a provider that reports several concurrently
    /// active allowances (Cursor). Empty for window-based providers, and
    /// absent from snapshots written before pools existed, which decode
    /// as empty and render exactly as they did.
    public let pools: [WidgetAllowancePool]
    public let fetchedAt: Date

    public init(
        provider: AgentProvider,
        currentWindowLabel: String,
        currentWindowDuration: TimeInterval? = nil,
        currentPercentLeft: Double?,
        currentResetAt: Date?,
        weeklyPercentLeft: Double?,
        weeklyResetAt: Date?,
        pools: [WidgetAllowancePool] = [],
        fetchedAt: Date
    ) {
        self.provider = provider
        self.currentWindowLabel = currentWindowLabel
        self.currentWindowDuration = currentWindowDuration
        self.currentPercentLeft = currentPercentLeft
        self.currentResetAt = currentResetAt
        self.weeklyPercentLeft = weeklyPercentLeft
        self.weeklyResetAt = weeklyResetAt
        self.pools = pools
        self.fetchedAt = fetchedAt
    }

    /// Hand-written for the same reason as `ProviderAllowance`'s: a
    /// snapshot written by an older app build has no `pools` key, and the
    /// widget must render it rather than fail the whole decode and drop
    /// to its "no data yet" state.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(AgentProvider.self, forKey: .provider)
        currentWindowLabel = try container.decode(String.self, forKey: .currentWindowLabel)
        // Absent from a snapshot written by a Mac that predates durations.
        // Decodes as nil, which simply means no window can be rolled
        // forward, exactly as before.
        currentWindowDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .currentWindowDuration)
        currentPercentLeft = try container.decodeIfPresent(Double.self, forKey: .currentPercentLeft)
        currentResetAt = try container.decodeIfPresent(Date.self, forKey: .currentResetAt)
        weeklyPercentLeft = try container.decodeIfPresent(Double.self, forKey: .weeklyPercentLeft)
        weeklyResetAt = try container.decodeIfPresent(Date.self, forKey: .weeklyResetAt)
        pools = try container.decodeIfPresent([WidgetAllowancePool].self, forKey: .pools) ?? []
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
    }

    /// "Updated 16h ago" once this provider's own reading is older than
    /// the widget's staleness threshold, nil while it is current.
    ///
    /// Judged from `fetchedAt`, when the Mac actually read the provider,
    /// never from the snapshot's `generatedAt`. When a read fails the Mac
    /// keeps its last good value, and every snapshot written afterwards
    /// carries that value forward under a new generation time, so the
    /// snapshot's age says nothing about how old these numbers are.
    public func staleLabel(now: Date) -> String? {
        guard WidgetDataFreshness.evaluate(generatedAt: fetchedAt, now: now) == .stale else { return nil }
        return "Updated \(WidgetSnapshotFormatting.lastUpdatedLabel(fetchedAt, now: now))"
    }

    /// The one reset every pool shares, when they genuinely share one.
    /// Cursor meters both pools against a single billing cycle, so
    /// repeating the same date under each bar would spend a line of a
    /// fixed canvas saying it twice. Nil whenever the resets differ, are
    /// missing, or there is only one pool, so a difference is never
    /// collapsed away. Lives here rather than in the widget view so the
    /// rule is testable and shared.
    public var sharedPoolResetAt: Date? {
        guard pools.count > 1 else { return nil }
        let resets = pools.compactMap(\.resetAt)
        guard resets.count == pools.count, let first = resets.first else { return nil }
        return resets.allSatisfy { $0 == first } ? first : nil
    }

    /// Individual allowance windows to display, derived from the stored
    /// current/weekly fields. Always includes the current window; the
    /// weekly window only appears when the provider actually reports one
    /// (Codex, for example, currently reports only a single window labeled
    /// "Weekly" with no separate secondary value). Not stored on disk: a
    /// display-layer projection over already-serialized fields, so it
    /// doesn't need Codable or a schema version bump.
    public var windows: [WidgetAllowanceWindow] {
        windows(asOf: nil)
    }

    /// The same projection, re-read as of `now`.
    ///
    /// Passing a date is what an iPhone does: its snapshot can be hours
    /// old, so a window whose reset has since passed is reported as the
    /// fresh window it now is rather than the spent one it was. Passing
    /// nil is what the desktop does, where the snapshot is seconds old
    /// and every figure still describes the window it was read from.
    public func windows(asOf now: Date?) -> [WidgetAllowanceWindow] {
        rawWindows.map { window in
            guard let now else { return window }
            let rolled = AllowanceWindowRollover.apply(
                percentLeft: window.percentLeft,
                resetAt: window.resetAt,
                duration: duration(of: window.kind),
                now: now
            )
            return WidgetAllowanceWindow(
                provider: window.provider,
                kind: window.kind,
                label: window.label,
                percentLeft: rolled.percentLeft,
                resetAt: rolled.resetAt,
                isDerived: rolled.isDerived
            )
        }
    }

    /// The period of a given window, where one is known. A pool states no
    /// period, so a pool never rolls forward.
    private func duration(of kind: WidgetAllowanceWindow.Kind) -> TimeInterval? {
        switch kind {
        case .current: currentWindowDuration
        case .weekly: AllowanceWindowRollover.weeklyDuration
        case .pool: nil
        }
    }

    private var rawWindows: [WidgetAllowanceWindow] {
        guard pools.isEmpty else {
            return pools.map { pool in
                WidgetAllowanceWindow(
                    provider: provider,
                    kind: .pool(pool.id),
                    label: pool.label,
                    percentLeft: pool.percentLeft,
                    resetAt: pool.resetAt
                )
            }
        }
        var result = [
            WidgetAllowanceWindow(
                provider: provider,
                kind: .current,
                label: currentWindowLabel,
                percentLeft: currentPercentLeft,
                resetAt: currentResetAt
            )
        ]
        if let weeklyPercentLeft {
            result.append(
                WidgetAllowanceWindow(
                    provider: provider,
                    kind: .weekly,
                    label: "Weekly",
                    percentLeft: weeklyPercentLeft,
                    resetAt: weeklyResetAt
                )
            )
        }
        return result
    }
}

/// A single allowance window ready for display: one bar, one percentage,
/// one label. Not Codable: it's a computed presentation over
/// `WidgetAllowanceSummary`'s stored fields, not part of the shared
/// snapshot's serialized schema.
/// One named sub-pool as carried in the shared snapshot. Normalized
/// display data only: no credential, no account identity, no raw response.
public struct WidgetAllowancePool: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let percentLeft: Double?
    public let resetAt: Date?

    public init(id: String, label: String, percentLeft: Double?, resetAt: Date?) {
        self.id = id
        self.label = label
        self.percentLeft = percentLeft
        self.resetAt = resetAt
    }
}

public struct WidgetAllowanceWindow: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case current
        case weekly
        /// Carries the pool's stable id so several pools from one
        /// provider stay individually identifiable in a ForEach.
        case pool(String)

        public var rawValue: String {
            switch self {
            case .current: "current"
            case .weekly: "weekly"
            case let .pool(id): id
            }
        }
    }

    public let provider: AgentProvider
    public let kind: Kind
    public let label: String
    public let percentLeft: Double?
    public let resetAt: Date?
    /// Set when `percentLeft` was inferred from a window having elapsed
    /// rather than read off the Mac. The caption marks it so an inferred
    /// figure is never mistaken for an observed one.
    public let isDerived: Bool

    public init(
        provider: AgentProvider,
        kind: Kind,
        label: String,
        percentLeft: Double?,
        resetAt: Date?,
        isDerived: Bool = false
    ) {
        self.provider = provider
        self.kind = kind
        self.label = label
        self.percentLeft = percentLeft
        self.resetAt = resetAt
        self.isDerived = isDerived
    }

    public var id: String {
        "\(provider.rawValue):\(kind.rawValue)"
    }

    public var normalizedProgress: Double? {
        percentLeft.map { value in
            // A non-finite percentage would propagate through the division
            // and reach a SwiftUI frame as NaN, which breaks layout rather
            // than drawing a wrong bar. Treat it as empty.
            guard value.isFinite else { return 0 }
            return min(max(value / 100, 0), 1)
        }
    }
}

public struct WidgetProviderSummary: Codable, Equatable, Sendable {
    public let provider: AgentProvider
    public let installed: Bool

    public init(provider: AgentProvider, installed: Bool) {
        self.provider = provider
        self.installed = installed
    }
}
