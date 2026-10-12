import Foundation

public protocol SyncedStateCaching: Sendable {
    func load() -> SyncedStateLoadResult
    func save(_ envelope: SyncedStateEnvelope) throws
}

/// The iPhone's local copy of the last envelope it retrieved, in the App
/// Group container the iOS app and its widget share. WidgetKit decides
/// when the widget may run, so the widget must be able to render from
/// what the app last fetched without a network round trip of its own.
///
/// Reading is safe by construction, matching `AppGroupSnapshotSource`:
/// every failure resolves to an explicit result, never a crash, and a
/// cached envelope is validated again on every read.
public struct AppGroupSyncedStateStore: SyncedStateCaching {
    public static let filename = "SyncedState.json"

    private let containerDirectory: @Sendable () -> URL?

    public init() {
        containerDirectory = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroupSnapshotSource.appGroupIdentifier
            )
        }
    }

    /// Testing seam, matching `AppGroupSnapshotSource`'s.
    public init(containerDirectory: @escaping @Sendable () -> URL?) {
        self.containerDirectory = containerDirectory
    }

    public func load() -> SyncedStateLoadResult {
        guard let directory = containerDirectory() else { return .notConfigured }
        let url = directory.appendingPathComponent(Self.filename)
        guard let data = try? Data(contentsOf: url) else { return .noSnapshotYet }
        guard let envelope = try? SyncedStateCodec.decode(data) else { return .corrupted }
        return .loaded(envelope)
    }

    #if DEBUG
    /// When the cache file was last written, for the iPhone's diagnostics.
    public func lastWriteDate() -> Date? {
        guard let directory = containerDirectory() else { return nil }
        let url = directory.appendingPathComponent(Self.filename)
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
    #endif

    public func save(_ envelope: SyncedStateEnvelope) throws {
        guard let directory = containerDirectory() else {
            throw WidgetSnapshotWriteError.containerUnavailable
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(Self.filename)
        try SyncedStateCodec.encode(envelope).write(to: url, options: .atomic)
    }
}
