import Foundation

public protocol CodexSessionDiscovering: Sendable {
    func discover() async throws -> [NormalizedEvent]
}

public protocol CodexThreadRequesting: Sendable {
    func readThreads() async throws -> Data
}

public enum CodexSessionDiscoveryError: Error, Equatable {
    case invalidResponse
    case unavailable
}

public enum CodexThreadListProtocol {
    public static let threadListRequest = Data(
        """
        {"method":"thread/list","id":8,"params":{"limit":50,"sortKey":"updated_at","sortDirection":"desc","sourceKinds":["appServer","cli","vscode"],"useStateDbOnly":true}}

        """.utf8
    )
}

public struct CodexSessionDiscoveryAdapter: CodexSessionDiscovering {
    public static let discoveryRetention: TimeInterval = 4 * 60 * 60
    public static let recentActivityDuration: TimeInterval = 20
    public static let refreshInterval: Duration = .seconds(15)

    private let requester: any CodexThreadRequesting
    private let workingDirectoryExists: @Sendable (String) -> Bool
    private let now: @Sendable () -> Date

    public init(
        requester: any CodexThreadRequesting,
        workingDirectoryExists: @escaping @Sendable (String) -> Bool = {
            FileManager.default.fileExists(atPath: $0)
        },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.requester = requester
        self.workingDirectoryExists = workingDirectoryExists
        self.now = now
    }

    public func discover() async throws -> [NormalizedEvent] {
        let response: ThreadListResponse
        do {
            response = try JSONDecoder().decode(
                ThreadListResponse.self,
                from: try await requester.readThreads()
            )
        } catch {
            throw CodexSessionDiscoveryError.invalidResponse
        }
        guard response.id == 8 else {
            throw CodexSessionDiscoveryError.invalidResponse
        }

        let currentTime = now()
        return try response.result.data.compactMap { thread in
            let updatedAt = Date(timeIntervalSince1970: thread.updatedAt)
            let age = currentTime.timeIntervalSince(updatedAt)
            guard age >= 0, age <= Self.discoveryRetention else { return nil }
            guard thread.cwd.hasPrefix("/") else { return nil }

            let phase = phase(for: thread.status, age: age)
            let projectName = workingDirectoryExists(thread.cwd)
                ? URL(fileURLWithPath: thread.cwd).lastPathComponent
                : AgentProvider.codex.displayName
            let event = NormalizedEvent(
                schemaVersion: ProductMetadata.schemaVersion,
                provider: .codex,
                surface: thread.source == "cli" ? .cli : .desktop,
                sessionID: HookNormalizer.sessionIdentifier(thread.id),
                turnID: nil,
                phase: phase,
                label: label(for: phase),
                toolCategory: nil,
                projectName: projectName.isEmpty ? AgentProvider.codex.displayName : projectName,
                workingDirectory: thread.cwd,
                sourceBundleID: thread.source == "cli" ? nil : "com.openai.codex",
                sourceProcessID: nil,
                sourceProcessStartedAt: nil,
                turnStartedAt: phase.isActive ? updatedAt : nil,
                updatedAt: updatedAt
            )
            try event.validate()
            return event
        }
    }

    private func phase(for status: ThreadStatus, age: TimeInterval) -> SessionPhase {
        switch status.type {
        case "active":
            return status.activeFlags?.contains("waitingOnApproval") == true
                ? .permission
                : .thinking
        case "systemError":
            return .failed
        default:
            return age <= Self.recentActivityDuration ? .thinking : .idle
        }
    }

    private func label(for phase: SessionPhase) -> String {
        switch phase {
        case .permission: "Awaiting permission"
        case .failed: "Failed"
        case .thinking: "Thinking"
        default: "Idle"
        }
    }
}

public enum SessionEventMerger {
    public static let hookFreshnessTolerance: TimeInterval = 10

    public static func merge(
        stored: [NormalizedEvent],
        discoveredCodex: [NormalizedEvent]
    ) -> [NormalizedEvent] {
        var merged = Dictionary(uniqueKeysWithValues: stored.map { (SessionKey($0), $0) })
        for discovered in discoveredCodex where discovered.provider == .codex {
            let key = SessionKey(discovered)
            if let storedEvent = merged[key],
               storedEvent.updatedAt.timeIntervalSince(discovered.updatedAt)
                >= -hookFreshnessTolerance {
                continue
            }
            merged[key] = discovered
        }
        return Array(merged.values)
    }
}

public struct CodexThreadListClient: CodexThreadRequesting {
    private let executableURL: URL

    public init(executableURL: URL) {
        self.executableURL = executableURL
    }

    public func readThreads() async throws -> Data {
        let executableURL = executableURL
        return try await Task.detached(priority: .utility) {
            let process = Process()
            let input = Pipe()
            let output = Pipe()
            process.executableURL = executableURL
            process.arguments = ["app-server"]
            process.standardInput = input
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                throw CodexSessionDiscoveryError.unavailable
            }

            let timeout = DispatchWorkItem {
                if process.isRunning { process.terminate() }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + 5,
                execute: timeout
            )
            defer {
                timeout.cancel()
                try? input.fileHandleForWriting.close()
                if process.isRunning { process.terminate() }
            }

            var initialized = false
            try input.fileHandleForWriting.write(contentsOf: CodexAppServerProtocol.initializeRequest)
            while let line = try output.fileHandleForReading.readJSONLine() {
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let id = (object["id"] as? NSNumber)?.intValue
                else { continue }
                if id == 1, !initialized {
                    initialized = true
                    try input.fileHandleForWriting.write(
                        contentsOf: CodexAppServerProtocol.initializedNotification
                            + CodexThreadListProtocol.threadListRequest
                    )
                } else if id == 8 {
                    return line
                }
            }
            throw CodexSessionDiscoveryError.invalidResponse
        }.value
    }
}

private struct ThreadListResponse: Decodable {
    let id: Int
    let result: ThreadListResult
}

private struct ThreadListResult: Decodable {
    let data: [CodexThread]
}

private struct CodexThread: Decodable {
    let id: String
    let cwd: String
    let updatedAt: TimeInterval
    let status: ThreadStatus
    let source: String
}

private struct ThreadStatus: Decodable {
    let type: String
    let activeFlags: [String]?
}

private extension FileHandle {
    func readJSONLine() throws -> Data? {
        var line = Data()
        while let byte = try read(upToCount: 1), !byte.isEmpty {
            line.append(byte)
            if byte[byte.startIndex] == UInt8(ascii: "\n") { return line }
        }
        return line.isEmpty ? nil : line
    }
}
