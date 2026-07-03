import Foundation

public enum AllowanceAdapterError: Error, Equatable, Sendable {
    case unsupported(String)
    case unavailable(String)
    case invalidResponse
    case rateLimited(retryAfter: TimeInterval?)
}

public protocol AllowanceProviding: Sendable {
    var provider: AgentProvider { get }
    func fetch() async throws -> ProviderAllowance
}

public struct UnsupportedClaudeAllowanceAdapter: AllowanceProviding {
    public let provider = AgentProvider.claude

    public init() {}

    public func fetch() async throws -> ProviderAllowance {
        throw AllowanceAdapterError.unsupported(
            "Anthropic does not document a programmatic subscription-allowance endpoint."
        )
    }
}

public struct UnavailableAllowanceAdapter: AllowanceProviding {
    public let provider: AgentProvider
    private let reason: String

    public init(provider: AgentProvider, reason: String) {
        self.provider = provider
        self.reason = reason
    }

    public func fetch() async throws -> ProviderAllowance {
        throw AllowanceAdapterError.unavailable(reason)
    }
}

public enum AllowanceRefreshPolicy {
    public static let turnCompletionDebounce: TimeInterval = 4
    public static let workingInterval: TimeInterval = 60
    public static let popoverMaximumAge: TimeInterval = 15
    public static let idleInterval: TimeInterval = 300
}
