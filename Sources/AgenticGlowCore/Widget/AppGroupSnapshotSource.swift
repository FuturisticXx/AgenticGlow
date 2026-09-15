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
    /// A snapshot file exists but this process is not allowed to read it.
    /// On macOS the group container is TCC-protected, so a widget binary
    /// whose signature does not carry the team-prefixed App Group (an
    /// unsigned local build, a stale extension registration) is refused at
    /// the kernel. That is not "the app hasn't run yet", and reporting it as
    /// such hid a wrong-binary failure behind a waiting message.
    case unreadable
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
    public static let appGroupIdentifier = "Z52AX2BH7T.group.com.twodamax.agenticglow"
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
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return Self.isMissingFile(error) ? .noSnapshotYet : .unreadable
        }
        guard let snapshot = try? JSONDecoder.agenticglow.decode(WidgetSnapshot.self, from: data) else {
            return .corrupted
        }
        // Decoding proves the shape, not the meaning. A snapshot written by
        // a different schema, or carrying counts that cannot exist, is not
        // data this build knows how to render.
        guard snapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion,
              snapshot.attentionCount >= 0,
              snapshot.activeCount >= 0 else {
            return .corrupted
        }
        return .loaded(snapshot)
    }

    /// Only a genuinely absent file means the app has not published yet.
    /// Every other read failure (permission refused, sandbox or TCC denial,
    /// an unreadable volume) is a different problem with a different fix.
    static func isMissingFile(_ error: any Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == CocoaError.fileReadNoSuchFile.rawValue || nsError.code == CocoaError.fileNoSuchFile.rawValue {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(ENOENT) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isMissingFile(underlying)
        }
        return false
    }
}
