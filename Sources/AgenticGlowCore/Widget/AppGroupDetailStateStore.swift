import Foundation

public protocol WidgetDetailStateStoring: Sendable {
    func load() -> WidgetDetailState
    func save(_ state: WidgetDetailState)
}

/// Stores the widget's temporary page state in the shared App Group
/// container, written by the widget extension's own intents.
///
/// Deliberately separate from the snapshot file: a page request must never
/// be able to corrupt or race the usage data the app publishes. Every
/// failure resolves to the empty state, which renders the overview, so a
/// missing or unreadable file can only ever fail toward normal.
public struct AppGroupDetailStateStore: WidgetDetailStateStoring {
    public static let filename = "WidgetDetailState.json"

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

    public func load() -> WidgetDetailState {
        guard
            let url = fileURL(),
            let data = try? Data(contentsOf: url),
            let state = try? JSONDecoder.agenticglow.decode(WidgetDetailState.self, from: data)
        else { return .empty }
        return state
    }

    public func save(_ state: WidgetDetailState) {
        guard let url = fileURL(), let data = try? JSONEncoder.agenticglow.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func fileURL() -> URL? {
        containerDirectory()?.appendingPathComponent(Self.filename)
    }
}
