import Foundation

public struct UsageResetEvent: Equatable, Sendable {
    public let key: UsageWindowKey
    public let percentLeft: Double?
    public let detectedAt: Date

    public init(key: UsageWindowKey, percentLeft: Double?, detectedAt: Date) {
        self.key = key
        self.percentLeft = percentLeft
        self.detectedAt = detectedAt
    }

    public var provider: AgentProvider { key.provider }
}

/// The last *known* state of one window. `.unknown` is never stored: an
/// observation we cannot trust must not overwrite what we already knew.
public struct UsageWindowEvidence: Equatable, Sendable {
    public let availability: UsageAvailability
    public let observedAt: Date

    public init(availability: UsageAvailability, observedAt: Date) {
        self.availability = availability
        self.observedAt = observedAt
    }
}

/// Detects usage returning by comparing consecutive *observations*, not by
/// checking whether a reset timestamp has passed. A reset time only says
/// when availability is expected; only a live reading proves it arrived.
///
/// The whole detector is a value type so the app layer can persist its
/// evidence and restore it after a relaunch, which is what keeps a restart
/// from replaying an alert that was already delivered.
public struct UsageResetDetector: Equatable, Sendable {
    public private(set) var evidence: [UsageWindowKey: UsageWindowEvidence]

    public init(evidence: [UsageWindowKey: UsageWindowEvidence] = [:]) {
        self.evidence = evidence
    }

    /// Folds one round of observations into the stored evidence and returns
    /// the windows whose usage just came back.
    public mutating func evaluate(_ observations: [UsageWindowObservation]) -> [UsageResetEvent] {
        var events: [UsageResetEvent] = []
        for observation in observations {
            // An untrusted reading carries the previous evidence forward
            // untouched, so exhausted -> unknown -> available still reads
            // as a reset while unknown -> available on its own stays quiet.
            guard observation.availability != .unknown else { continue }
            let previous = evidence[observation.key]?.availability
            evidence[observation.key] = UsageWindowEvidence(
                availability: observation.availability,
                observedAt: observation.observedAt
            )
            guard previous == .exhausted, observation.availability != .exhausted else { continue }
            events.append(UsageResetEvent(
                key: observation.key,
                percentLeft: observation.percentLeft,
                detectedAt: observation.observedAt
            ))
        }
        return events
    }

    /// Drops everything remembered about a provider. Called when the user
    /// turns that provider's usage access off, matching the allowance
    /// cache deletion so no stale exhaustion can fire weeks later.
    public mutating func forget(provider: AgentProvider) {
        evidence = evidence.filter { $0.key.provider != provider }
    }
}
