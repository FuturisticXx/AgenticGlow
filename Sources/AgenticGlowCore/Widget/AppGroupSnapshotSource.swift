import Foundation

/// Distinguishes *why* no usable snapshot is available, so the widget can
/// show an honest, specific state instead of one generic "no data" blob.
public enum WidgetSnapshotLoadResult: Equatable, Sendable {
    /// The App Group container itself isn't available: the entitlement
    /// is unavailable or was removed.
    case notConfigured
    /// The container exists but AgenticGlow has not written a snapshot yet
    /// (fresh install, or the app hasn't launched since).
    case noSnapshotYet
    /// A snapshot file exists but could not be decoded (corrupted on disk,
    /// or an unreadable schema).
    case corrupted
    case loaded(WidgetSnapshot)
}

public protocol WidgetSnapshotLoading: Sendable {
    func loadSnapshot() -> WidgetSnapshotLoadResult
}

/// Reads the widget-safe snapshot AgenticGlow writes to the shared App
/// Group container. Safe by construction: it never throws or crashes, and
/// every failure mode maps to an explicit, honest result case instead of
/// being flattened into "no data."
public struct AppGroupSnapshotSource: WidgetSnapshotLoading {
    public static let appGroupIdentifier = "group.com.twodamax.agenticglow"
    public static let snapshotFilename = "WidgetSnapshot.json"

    private let containerDirectory: @Sendable () -> URL?

    public init() {
        containerDirectory = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
        }
    }

    /// Testing seam: load from a known directory instead of resolving the
    /// real App Group container, so decode-safety can be exercised without
    /// the entitlement being present.
    init(containerDirectory: @escaping @Sendable () -> URL?) {
        self.containerDirectory = containerDirectory
    }

    public func loadSnapshot() -> WidgetSnapshotLoadResult {
        guard let directory = containerDirectory() else { return .notConfigured }
        let url = directory.appendingPathComponent(Self.snapshotFilename)
        guard let data = try? Data(contentsOf: url) else { return .noSnapshotYet }
        guard let snapshot = try? JSONDecoder.agenticglow.decode(WidgetSnapshot.self, from: data) else {
            return .corrupted
        }
        return .loaded(snapshot)
    }
}
