import Foundation
import KlarityCore

protocol SyntheticEventTesting {
    func run(provider: AgentProvider, helperURL: URL) throws -> Bool
}

struct SyntheticEventService: SyntheticEventTesting {
    let store: SessionStateStoring

    func run(provider: AgentProvider, helperURL: URL) throws -> Bool {
        let sessionID = "klarity-setup-\(UUID().uuidString)"
        let payload = try JSONSerialization.data(withJSONObject: [
            "session_id": sessionID,
            "turn_id": "setup",
            "cwd": FileManager.default.homeDirectoryForCurrentUser.path
        ])
        let process = Process()
        let input = Pipe()
        process.executableURL = helperURL
        process.arguments = [provider.rawValue, HookEventKind.userPromptSubmit.rawValue, "--klarity-hook"]
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        try input.fileHandleForWriting.write(contentsOf: payload)
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        let key = SessionKey(provider: provider, sessionID: sessionID)
        defer { try? store.remove(key) }
        guard process.terminationStatus == 0 else { return false }
        return (try? store.load(key)) != nil
    }
}
