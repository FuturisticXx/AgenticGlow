import Foundation

public protocol CodexRateLimitRequesting: Sendable {
    func readRateLimits() async throws -> Data
}

public struct CodexAllowanceAdapter: AllowanceProviding {
    public let provider = AgentProvider.codex
    private let requester: any CodexRateLimitRequesting
    private let now: @Sendable () -> Date

    public init(
        requester: any CodexRateLimitRequesting,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.requester = requester
        self.now = now
    }

    public func fetch() async throws -> ProviderAllowance {
        let data = try await requester.readRateLimits()
        do {
            return try CodexAllowanceNormalizer.normalize(data, fetchedAt: now())
        } catch {
            throw AllowanceAdapterError.invalidResponse
        }
    }
}

public enum CodexAppServerProtocol {
    public static let rateLimitRequest = Data(
        """
        {"method":"initialize","id":1,"params":{"clientInfo":{"name":"agenticglow","title":"AgenticGlow","version":"1.0"}}}
        {"method":"initialized","params":{}}
        {"method":"account/rateLimits/read","id":7,"params":{}}

        """.utf8
    )

    public static func extractRateLimitResponse(from stream: Data) throws -> Data {
        for line in stream.split(separator: UInt8(ascii: "\n")) {
            let data = Data(line)
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                (object["id"] as? NSNumber)?.intValue == 7
            else { continue }
            if let result = object["result"] as? [String: Any], result["rateLimits"] != nil {
                return data
            }
            if let error = object["error"] as? [String: Any],
               (error["code"] as? NSNumber)?.intValue == 429 {
                let details = error["data"] as? [String: Any]
                let retryAfter = (details?["retryAfterSeconds"] as? NSNumber)?.doubleValue
                throw AllowanceAdapterError.rateLimited(retryAfter: retryAfter)
            }
        }
        throw AllowanceAdapterError.invalidResponse
    }
}

public struct CodexAppServerClient: CodexRateLimitRequesting {
    private let executableURL: URL

    public init(executableURL: URL) {
        self.executableURL = executableURL
    }

    public func readRateLimits() async throws -> Data {
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
                throw AllowanceAdapterError.unavailable("Codex is not installed or could not start.")
            }

            let timeout = DispatchWorkItem {
                if process.isRunning { process.terminate() }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + 15,
                execute: timeout
            )
            defer { timeout.cancel() }

            try input.fileHandleForWriting.write(contentsOf: CodexAppServerProtocol.rateLimitRequest)
            try input.fileHandleForWriting.close()
            let response = try output.fileHandleForReading.readToEnd() ?? Data()
            process.waitUntilExit()
            return try CodexAppServerProtocol.extractRateLimitResponse(from: response)
        }.value
    }
}
