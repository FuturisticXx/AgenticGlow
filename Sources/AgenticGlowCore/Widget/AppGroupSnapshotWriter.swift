import Foundation

public enum WidgetSnapshotWriteError: Error, Equatable, Sendable {
    case containerUnavailable
}

public protocol WidgetSnapshotWriting: Sendable {
    func write(_ snapshot: WidgetSnapshot) throws
}

/// Writes the widget-safe snapshot to the shared App Group container. Mirrors
/// AppGroupSnapshotSource's read side: same container/filename, same
/// testing seam for exercising the write path without the entitlement.
public struct AppGroupSnapshotWriter: WidgetSnapshotWriting {
    private let containerDirectory: @Sendable () -> URL?

    public init() {
        containerDirectory = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroupSnapshotSource.appGroupIdentifier
            )
        }
    }

    init(containerDirectory: @escaping @Sendable () -> URL?) {
        self.containerDirectory = containerDirectory
    }

    public func write(_ snapshot: WidgetSnapshot) throws {
        guard let directory = containerDirectory() else {
            throw WidgetSnapshotWriteError.containerUnavailable
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(AppGroupSnapshotSource.snapshotFilename)
        let data = try JSONEncoder.agenticglow.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}
