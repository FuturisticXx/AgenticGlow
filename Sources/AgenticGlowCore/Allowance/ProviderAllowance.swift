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
    /// Named sub-pools for providers whose plan splits into several
    /// concurrently active allowances. Empty for window-based providers
    /// (Codex, Claude), which keep using the current/weekly fields.
    /// Absent from allowances cached before pools existed, which decode
    /// as empty and behave exactly as they did.
    public let pools: [AllowancePool]
    public let fetchedAt: Date

    public init(
        provider: AgentProvider,
        currentWindowLabel: String,
        currentPercentUsed: Double?,
        currentResetAt: Date?,
        weeklyPercentUsed: Double?,
        weeklyResetAt: Date?,
        pools: [AllowancePool] = [],
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
        self.pools = pools
        self.fetchedAt = fetchedAt
    }

    /// Hand-written so an allowance cached by an older build, whose JSON
    /// has no `pools` key, still decodes instead of dropping the whole
    /// cache entry and showing the provider as unavailable.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(AgentProvider.self, forKey: .provider)
        currentWindowLabel = try container.decode(String.self, forKey: .currentWindowLabel)
        // Clamped here as well as in the designated initializer: a cache
        // file is untrusted input, and decoding bypasses that initializer.
        currentPercentUsed = Self.clamp(try container.decodeIfPresent(Double.self, forKey: .currentPercentUsed))
        currentPercentLeft = Self.clamp(try container.decodeIfPresent(Double.self, forKey: .currentPercentLeft))
        currentResetAt = try container.decodeIfPresent(Date.self, forKey: .currentResetAt)
        weeklyPercentUsed = Self.clamp(try container.decodeIfPresent(Double.self, forKey: .weeklyPercentUsed))
        weeklyPercentLeft = Self.clamp(try container.decodeIfPresent(Double.self, forKey: .weeklyPercentLeft))
        weeklyResetAt = try container.decodeIfPresent(Date.self, forKey: .weeklyResetAt)
        pools = try container.decodeIfPresent([AllowancePool].self, forKey: .pools) ?? []
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
    }

    private static func clamp(_ value: Double?) -> Double? {
        value.map { $0.isFinite ? min(100, max(0, $0)) : 0 }
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
