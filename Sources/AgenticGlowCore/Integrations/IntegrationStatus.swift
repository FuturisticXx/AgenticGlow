import Foundation

public struct IntegrationStatus: Equatable, Sendable {
    public let provider: AgentProvider
    public let installed: Bool
    public let requiresTrustReview: Bool
    public let installedEvents: [HookEventKind]
    public let issue: String?

    public init(
        provider: AgentProvider,
        installed: Bool,
        requiresTrustReview: Bool,
        installedEvents: [HookEventKind],
        issue: String?
    ) {
        self.provider = provider
        self.installed = installed
        self.requiresTrustReview = requiresTrustReview
        self.installedEvents = installedEvents
        self.issue = issue
    }
}

public protocol ProviderIntegrationManaging {
    var provider: AgentProvider { get }
    func install() throws
    func repair() throws
    func remove() throws
    func status() throws -> IntegrationStatus
}
