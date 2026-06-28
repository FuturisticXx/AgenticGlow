import Foundation

public protocol DiagnosticLogging {
    func record(
        provider: AgentProvider,
        event: HookEventKind,
        sessionID: String,
        result: String,
        rawPayload: String?
    )
}

public final class DiagnosticLogger: DiagnosticLogging {
    private let enabled: Bool
    private let url: URL
    private let lock = NSLock()

    public init(enabled: Bool, url: URL) {
        self.enabled = enabled
        self.url = url
    }

    public func record(
        provider: AgentProvider,
        event: HookEventKind,
        sessionID: String,
        result: String,
        rawPayload: String? = nil
    ) {
        guard enabled else { return }
        let line = "\(ISO8601DateFormatter().string(from: Date())) provider=\(provider.rawValue) event=\(event.rawValue) session=\(sessionID) result=\(result)\n"
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        }
        _ = rawPayload
    }
}
