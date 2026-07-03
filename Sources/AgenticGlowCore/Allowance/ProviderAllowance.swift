import Foundation

public struct ProviderAllowance: Codable, Equatable, Sendable {
    public let provider: AgentProvider
    public let currentWindowLabel: String
    public let currentPercentUsed: Double?
    public let currentPercentLeft: Double?
    public let currentResetAt: Date?
    public let weeklyPercentUsed: Double?
    public let weeklyPercentLeft: Double?
    public let weeklyResetAt: Date?
    public let fetchedAt: Date

    public init(
        provider: AgentProvider,
        currentWindowLabel: String,
        currentPercentUsed: Double?,
        currentResetAt: Date?,
        weeklyPercentUsed: Double?,
        weeklyResetAt: Date?,
        fetchedAt: Date
    ) {
        self.provider = provider
        self.currentWindowLabel = currentWindowLabel
        self.currentPercentUsed = Self.clamp(currentPercentUsed)
        self.currentPercentLeft = Self.remaining(from: currentPercentUsed)
        self.currentResetAt = currentResetAt
        self.weeklyPercentUsed = Self.clamp(weeklyPercentUsed)
        self.weeklyPercentLeft = Self.remaining(from: weeklyPercentUsed)
        self.weeklyResetAt = weeklyResetAt
        self.fetchedAt = fetchedAt
    }

    private static func clamp(_ value: Double?) -> Double? {
        value.map { min(100, max(0, $0)) }
    }

    private static func remaining(from used: Double?) -> Double? {
        clamp(used).map { 100 - $0 }
    }
}

public enum AllowanceFreshness: Equatable, Sendable {
    case fresh
    case stale
}

public enum AllowanceAvailability: Equatable, Sendable {
    case off
    case loading
    case available(ProviderAllowance, AllowanceFreshness)
    case unavailable(String)
}
