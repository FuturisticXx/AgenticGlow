import Foundation

public enum SyncedStateValidationError: Error, Equatable, Sendable {
    case malformed
    case payloadTooLarge
    case unsupportedEnvelopeSchema(Int)
    case unsupportedSnapshotSchema(Int)
    case invalidSourceMac
    case invalidCounts
    case tooManySessions(Int)
    case invalidSession
    case invalidAllowance
    case observedInTheFuture
}

/// Bounds every synchronized envelope must satisfy before it is rendered.
///
/// Decoding proves the shape; this proves the meaning. A record written
/// by a build with a different schema, or one carrying values that cannot
/// have come from `WidgetSnapshotBuilder`, is rejected as a whole rather
/// than rendered partially, so the widget can never show a session list
/// or a percentage the Mac did not produce.
public enum SyncedStateValidator {
    public static let maximumMacNameLength = 128
    public static let maximumTextLength = 256
    public static let maximumPools = 8
    /// How far ahead of the receiver's clock an observation may claim to
    /// be before it is treated as corrupt rather than as clock skew.
    public static let maximumFutureSkew: TimeInterval = 24 * 60 * 60

    public static func validate(_ envelope: SyncedStateEnvelope, now: Date = Date()) throws {
        guard envelope.schemaVersion == SyncedStateEnvelope.currentSchemaVersion else {
            throw SyncedStateValidationError.unsupportedEnvelopeSchema(envelope.schemaVersion)
        }
        let snapshot = envelope.snapshot
        guard snapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion else {
            throw SyncedStateValidationError.unsupportedSnapshotSchema(snapshot.schemaVersion)
        }
        guard
            UUID(uuidString: envelope.sourceMacID) != nil,
            !envelope.sourceMacName.isEmpty,
            envelope.sourceMacName.count <= maximumMacNameLength
        else { throw SyncedStateValidationError.invalidSourceMac }
        guard envelope.observedAt.timeIntervalSince(now) <= maximumFutureSkew else {
            throw SyncedStateValidationError.observedInTheFuture
        }
        guard snapshot.attentionCount >= 0, snapshot.activeCount >= 0, snapshot.revision >= 0 else {
            throw SyncedStateValidationError.invalidCounts
        }
        guard snapshot.sessions.count <= WidgetSnapshotBuilder.maximumSessions else {
            throw SyncedStateValidationError.tooManySessions(snapshot.sessions.count)
        }
        for session in snapshot.sessions {
            guard
                !session.sessionID.isEmpty,
                session.sessionID.count <= maximumTextLength,
                !session.projectName.isEmpty,
                session.projectName.count <= maximumTextLength,
                (session.compactDetail?.count ?? 0) <= maximumTextLength,
                (session.elapsedSeconds ?? 0) >= 0
            else { throw SyncedStateValidationError.invalidSession }
        }
        for allowance in snapshot.allowances {
            guard
                allowance.currentWindowLabel.count <= maximumTextLength,
                isValidPercent(allowance.currentPercentLeft),
                isValidPercent(allowance.weeklyPercentLeft),
                allowance.pools.count <= maximumPools
            else { throw SyncedStateValidationError.invalidAllowance }
            for pool in allowance.pools {
                guard
                    !pool.id.isEmpty,
                    pool.id.count <= maximumTextLength,
                    pool.label.count <= maximumTextLength,
                    isValidPercent(pool.percentLeft)
                else { throw SyncedStateValidationError.invalidAllowance }
            }
        }
    }

    /// A missing percentage is "unknown", which is valid; a present one
    /// must be a real number the bar can draw.
    private static func isValidPercent(_ value: Double?) -> Bool {
        guard let value else { return true }
        return value.isFinite && value >= 0 && value <= 100
    }
}
