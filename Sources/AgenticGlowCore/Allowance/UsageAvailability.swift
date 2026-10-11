import Foundation

/// Provider-neutral view of one usage window's headroom. Derived from
/// `ProviderAllowance` so reset detection never needs to know whether a
/// window came from Codex's app-server or Claude's usage endpoint.
public enum UsageAvailability: String, Codable, Equatable, Sendable {
    /// No trustworthy observation. Covers a failed fetch, a stale cache
    /// replayed after a failure, a provider that is off, and a window the
    /// provider stopped reporting. Never proof of anything.
    case unknown
    case available
    case approachingLimit
    case exhausted
}

/// Identifies one window of one provider. Codex renames its windows by
/// duration when an account's plan changes, so a renamed window is simply a
/// new key that starts at `.unknown` rather than a false transition.
public struct UsageWindowKey: Hashable, Codable, Sendable {
    public let provider: AgentProvider
    public let windowLabel: String

    public init(provider: AgentProvider, windowLabel: String) {
        self.provider = provider
        self.windowLabel = windowLabel
    }

    /// Label used by the weekly window across the allowance layer. Matches
    /// `AllowanceWarning` and `QuotaAlertTracker` so all three surfaces
    /// name the same window the same way.
    public static let weeklyLabel = "week"

    /// Human phrasing for notification copy. Codex labels its windows by
    /// duration, so both "5h" and "Weekly" can arrive as a current window.
    public var spokenWindowName: String {
        switch windowLabel {
        case Self.weeklyLabel, "Weekly": "weekly"
        case "5h": "5-hour"
        case "Current": "current"
        default: windowLabel.lowercased()
        }
    }
}

public struct UsageWindowObservation: Equatable, Sendable {
    public let key: UsageWindowKey
    public let availability: UsageAvailability
    public let percentLeft: Double?
    public let expectedReset: Date?
    public let observedAt: Date

    public init(
        key: UsageWindowKey,
        availability: UsageAvailability,
        percentLeft: Double?,
        expectedReset: Date?,
        observedAt: Date
    ) {
        self.key = key
        self.availability = availability
        self.percentLeft = percentLeft
        self.expectedReset = expectedReset
        self.observedAt = observedAt
    }
}

/// Turns whatever the refresh coordinator currently holds for a provider
/// into provider-neutral window observations.
public enum UsageWindowReader {
    public static func observations(
        provider: AgentProvider,
        state: AllowanceAvailability,
        now: Date
    ) -> [UsageWindowObservation] {
        switch state {
        case .off, .loading:
            // Nothing observed. An empty result deliberately leaves any
            // persisted evidence untouched rather than clearing it.
            return []
        case .unavailable:
            return []
        case let .available(allowance, freshness):
            // A stale value is the last successful fetch replayed after a
            // failure. Treating it as a live reading is exactly how a
            // network blip could fake a reset, so it observes as unknown.
            let trusted = freshness == .fresh
            return windows(in: allowance).map { window in
                UsageWindowObservation(
                    key: UsageWindowKey(
                        provider: provider,
                        windowLabel: window.label
                    ),
                    availability: trusted
                        ? availability(forPercentLeft: window.percentLeft)
                        : .unknown,
                    percentLeft: window.percentLeft,
                    expectedReset: window.resetAt,
                    observedAt: now
                )
            }
        }
    }

    public static func availability(forPercentLeft percentLeft: Double?) -> UsageAvailability {
        guard let percentLeft else { return .unknown }
        if percentLeft <= 0 { return .exhausted }
        if percentLeft < AllowanceWarning.thresholdPercentLeft { return .approachingLimit }
        return .available
    }

    private static func windows(in allowance: ProviderAllowance) -> [AllowanceWarning.Window] {
        var windows: [AllowanceWarning.Window] = []
        if let left = allowance.currentPercentLeft {
            windows.append(AllowanceWarning.Window(
                label: allowance.currentWindowLabel,
                percentLeft: left,
                resetAt: allowance.currentResetAt
            ))
        }
        if let left = allowance.weeklyPercentLeft {
            windows.append(AllowanceWarning.Window(
                label: UsageWindowKey.weeklyLabel,
                percentLeft: left,
                resetAt: allowance.weeklyResetAt
            ))
        }
        return windows
    }
}
