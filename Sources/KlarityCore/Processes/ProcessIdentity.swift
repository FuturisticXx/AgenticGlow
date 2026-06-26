import Foundation

public struct ProcessIdentity: Codable, Equatable, Sendable {
    public let processID: Int32
    public let startedAt: Date?
    public let bundleIdentifier: String?

    public init(processID: Int32, startedAt: Date?, bundleIdentifier: String?) {
        self.processID = processID
        self.startedAt = startedAt
        self.bundleIdentifier = bundleIdentifier
    }
}

#if DEBUG
public extension ProcessIdentity {
    static let fixture = ProcessIdentity(
        processID: 123,
        startedAt: Date(timeIntervalSince1970: 100),
        bundleIdentifier: "com.openai.codex"
    )
}

public extension NormalizedEvent {
    static func testEvent(
        provider: AgentProvider,
        phase: SessionPhase,
        turnStartedAt: Date?
    ) -> Self {
        .init(
            schemaVersion: 1,
            provider: provider,
            surface: .cli,
            sessionID: "\(provider.rawValue)-session",
            turnID: "turn",
            phase: phase,
            label: phase == .thinking ? "Thinking" : phase.rawValue,
            toolCategory: nil,
            projectName: "Klarity",
            workingDirectory: "/tmp/Klarity",
            sourceBundleID: "com.apple.Terminal",
            sourceProcessID: 123,
            sourceProcessStartedAt: Date(timeIntervalSince1970: 100),
            turnStartedAt: turnStartedAt,
            updatedAt: Date(timeIntervalSince1970: 120)
        )
    }
}
#endif
