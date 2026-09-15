import Foundation

public struct SessionKey: Hashable, Sendable {
    public let provider: AgentProvider
    public let sessionID: String

    public init(provider: AgentProvider, sessionID: String) {
        self.provider = provider
        self.sessionID = sessionID
    }

    public init(_ event: NormalizedEvent) {
        self.init(provider: event.provider, sessionID: event.sessionID)
    }

    public var filename: String {
        "\(provider.rawValue)-\(sessionID).json"
    }
}
