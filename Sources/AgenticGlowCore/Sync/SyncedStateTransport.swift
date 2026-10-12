import Foundation

/// The Mac side of synchronization: hands one envelope to iCloud.
public protocol SyncedStatePublishing: Sendable {
    func publish(_ envelope: SyncedStateEnvelope) async throws
}

/// The iPhone side: retrieves the most recently published envelope, or
/// nil when no Mac has published yet.
public protocol SyncedStateFetching: Sendable {
    func fetchLatest() async throws -> SyncedStateEnvelope?
}

/// Which of several Macs' envelopes the iPhone shows. One Mac today, but
/// the rule is the one a future picker would default to, so adding a
/// second Mac changes no data.
public enum SyncedStateSelection {
    public static func mostRecentlyObserved(_ envelopes: [SyncedStateEnvelope]) -> SyncedStateEnvelope? {
        envelopes.max { $0.observedAt < $1.observedAt }
    }
}

/// Why no usable envelope is available, mirroring
/// `WidgetSnapshotLoadResult` so the widget's honest empty states carry
/// over unchanged.
public enum SyncedStateLoadResult: Equatable, Sendable {
    /// The App Group container is unavailable.
    case notConfigured
    /// Nothing cached and nothing fetched: no Mac has published yet, or
    /// this iPhone is not signed in to the same iCloud account.
    case noSnapshotYet
    /// Something was there but failed to decode or validate.
    case corrupted
    case loaded(SyncedStateEnvelope)

    /// The desktop widget's own load result, so the shared views render
    /// the same states from either source.
    public var snapshotLoadResult: WidgetSnapshotLoadResult {
        switch self {
        case .notConfigured: .notConfigured
        case .noSnapshotYet: .noSnapshotYet
        case .corrupted: .corrupted
        case let .loaded(envelope): .loaded(envelope.snapshot)
        }
    }
}

public protocol SyncedStateLoading: Sendable {
    func loadSyncedState() async -> SyncedStateLoadResult
}
