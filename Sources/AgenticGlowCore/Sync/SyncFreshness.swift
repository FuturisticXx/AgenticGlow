import Foundation

/// How much an iPhone may trust what it holds about a Mac.
///
/// Keyed off the envelope's `observedAt`, the Mac's own statement of when
/// it last looked, never off when the iPhone fetched. The Mac republishes
/// on every meaningful change and on a heartbeat while idle, so a quiet
/// Mac still reads as fresh; a Mac that stopped reporting drifts through
/// stale into offline on the same clock whether or not anything reaches
/// the phone in between.
public enum SyncFreshness: Equatable, Sendable {
    /// Within the desktop widget's own staleness threshold: shown as live.
    case fresh(age: TimeInterval)
    /// Past that threshold but recent enough that the state is probably
    /// still roughly right: shown with its age, timers hidden.
    case stale(age: TimeInterval)
    /// The Mac has missed enough heartbeats that its state can no longer
    /// stand for current activity: sessions are withdrawn, allowances
    /// stay with a last-seen line.
    case offline(age: TimeInterval)

    /// How often an idle Mac republishes unchanged state. Matches the
    /// app's idle allowance refresh cadence (`AllowanceRefreshPolicy`),
    /// which is also the cadence the desktop widget's own threshold was
    /// set against.
    public static let heartbeatInterval: TimeInterval = 5 * 60
    /// The desktop widget's threshold, reused so both widgets agree on
    /// what "current" means: three missed heartbeats.
    public static let staleThreshold: TimeInterval = WidgetDataFreshness.staleThreshold
    /// Twelve missed heartbeats. Past this a session marked "Thinking"
    /// almost certainly is not, so the list is withdrawn rather than shown
    /// with a caveat.
    public static let offlineThreshold: TimeInterval = 60 * 60

    public static func evaluate(observedAt: Date, now: Date) -> SyncFreshness {
        // A clock ahead of the phone's reads as "just now", never as a
        // negative age.
        let age = max(0, now.timeIntervalSince(observedAt))
        if age > offlineThreshold { return .offline(age: age) }
        if age > staleThreshold { return .stale(age: age) }
        return .fresh(age: age)
    }

    public var age: TimeInterval {
        switch self {
        case let .fresh(age), let .stale(age), let .offline(age): age
        }
    }

    public var isFresh: Bool {
        if case .fresh = self { return true }
        return false
    }

    public var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }

    /// "fresh (3m)", "stale (32m)", "offline (1d 15h)": the state and its
    /// age, for diagnostics.
    public var summary: String {
        let name: String
        switch self {
        case .fresh: name = "fresh"
        case .stale: name = "stale"
        case .offline: name = "offline"
        }
        let minutes = Int(age / 60)
        let hours = minutes / 60
        let days = hours / 24
        let ageLabel = days > 0 ? "\(days)d \(hours % 24)h" : hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
        return "\(name) (\(ageLabel))"
    }

    /// The moments after `observedAt` at which the presentation changes,
    /// so a timeline can carry an entry for each and the widget flips to
    /// stale and then offline on time even if nothing wakes it. One
    /// second past each threshold, because an entry rendered exactly at
    /// the threshold still evaluates as the earlier state (the
    /// thresholds are inclusive, as the desktop widget's is).
    public static func transitions(after observedAt: Date, now: Date) -> [Date] {
        [observedAt.addingTimeInterval(staleThreshold + 1), observedAt.addingTimeInterval(offlineThreshold + 1)]
            .filter { $0 > now }
    }
}

/// Whether the Mac should publish on this refresh tick.
public enum SyncPublishingPolicy {
    public static func shouldPublish(changed: Bool, lastPublishedAt: Date?, now: Date) -> Bool {
        if changed { return true }
        guard let lastPublishedAt else { return true }
        return now.timeIntervalSince(lastPublishedAt) >= SyncFreshness.heartbeatInterval
    }
}

/// The footer line the iPhone widget shows under synchronized content.
public enum SyncStatusCopy {
    public static func footer(macName: String, freshness: SyncFreshness, observedAt: Date, now: Date) -> String {
        let age = WidgetSnapshotFormatting.lastUpdatedLabel(observedAt, now: now)
        switch freshness {
        case .fresh:
            return "\(macName) · \(age)"
        case .stale:
            return "\(macName) · Updated \(age.lowercasedFirstCharacter)"
        case .offline:
            return "\(macName) unavailable · last seen \(age.lowercasedFirstCharacter)"
        }
    }

    /// The small family's footer: the same states without the Mac's
    /// name, which has no room on a 155pt canvas.
    public static func compactFooter(freshness: SyncFreshness, observedAt: Date, now: Date) -> String {
        let age = WidgetSnapshotFormatting.lastUpdatedLabel(observedAt, now: now)
        switch freshness {
        case .fresh: return age
        case .stale: return "Updated \(age.lowercasedFirstCharacter)"
        case .offline: return offlineSessionsLine
        }
    }

    /// What replaces the session list once the Mac is offline.
    public static let offlineSessionsLine = "Mac unavailable"
}

private extension String {
    var lowercasedFirstCharacter: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}

/// What a synchronized widget entry knows about where its snapshot came
/// from. Present only on the iPhone; the desktop widget renders its own
/// Mac's snapshot and carries nil, which leaves its layout untouched.
public struct WidgetSyncProvenance: Equatable, Sendable {
    public let sourceMacName: String
    public let observedAt: Date

    public init(sourceMacName: String, observedAt: Date) {
        self.sourceMacName = sourceMacName
        self.observedAt = observedAt
    }

    public init(_ envelope: SyncedStateEnvelope) {
        self.init(sourceMacName: envelope.sourceMacName, observedAt: envelope.observedAt)
    }

    public func freshness(now: Date) -> SyncFreshness {
        SyncFreshness.evaluate(observedAt: observedAt, now: now)
    }

    public func footer(now: Date) -> String {
        SyncStatusCopy.footer(macName: sourceMacName, freshness: freshness(now: now), observedAt: observedAt, now: now)
    }

    public func compactFooter(now: Date) -> String {
        SyncStatusCopy.compactFooter(freshness: freshness(now: now), observedAt: observedAt, now: now)
    }
}
