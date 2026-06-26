import Foundation

public struct ProcessIdentityResolver: Sendable {
    public static let live = ProcessIdentityResolver()

    public init() {}

    public func resolve(
        provider: AgentProvider,
        environment: [String: String]
    ) -> ProcessIdentity? {
        _ = provider
        _ = environment
        return nil
    }
}
