import Foundation

public enum AllowanceRefreshReason: Sendable {
    case manual
    case enabled
    case turnCompleted
    case working
    case popoverOpened
    case idle
}

public actor AllowanceRefreshCoordinator {
    private let adapters: [AgentProvider: any AllowanceProviding]
    private let cache: any AllowanceCaching
    private let now: @Sendable () -> Date
    private let jitter: @Sendable () -> TimeInterval
    private var enabled: Set<AgentProvider> = []
    private var states: [AgentProvider: AllowanceAvailability] = [:]
    private var inFlight: Set<AgentProvider> = []
    private var lastAttempt: [AgentProvider: Date] = [:]
    private var failureCount: [AgentProvider: Int] = [:]
    private var retryAfter: [AgentProvider: Date] = [:]
    private var suspended = false

    public init(
        adapters: [any AllowanceProviding],
        cache: any AllowanceCaching,
        now: @escaping @Sendable () -> Date = Date.init,
        jitter: @escaping @Sendable () -> TimeInterval = { Double.random(in: 0...1) }
    ) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.provider, $0) })
        self.cache = cache
        self.now = now
        self.jitter = jitter
    }

    public func setEnabled(_ value: Bool, provider: AgentProvider) async {
        if value {
            enabled.insert(provider)
            states[provider] = .loading
            await refreshProvider(provider)
        } else {
            enabled.remove(provider)
            states[provider] = .off
            try? cache.remove(provider)
        }
    }

    public func refresh(_ reason: AllowanceRefreshReason) async {
        guard !suspended else { return }
        for provider in AgentProvider.allCases where enabled.contains(provider) {
            guard shouldRefresh(provider, reason: reason) else { continue }
            await refreshProvider(provider)
        }
    }

    public func state(for provider: AgentProvider) -> AllowanceAvailability {
        states[provider] ?? .off
    }

    public func setSuspended(_ value: Bool) {
        suspended = value
    }

    private func refreshProvider(_ provider: AgentProvider) async {
        guard
            enabled.contains(provider),
            !suspended,
            !inFlight.contains(provider),
            let adapter = adapters[provider]
        else { return }
        inFlight.insert(provider)
        lastAttempt[provider] = now()
        defer { inFlight.remove(provider) }
        do {
            let allowance = try await adapter.fetch()
            guard enabled.contains(provider) else { return }
            try cache.save(allowance)
            failureCount[provider] = 0
            retryAfter[provider] = nil
            states[provider] = .available(allowance, .fresh)
        } catch let error as AllowanceAdapterError {
            guard enabled.contains(provider) else { return }
            recordFailure(provider, retryDelay: error.retryDelay)
            let cached = try? cache.load(provider)
            if let cached {
                states[provider] = .available(cached, .stale)
            } else {
                switch error {
                case let .unsupported(reason), let .unavailable(reason):
                    states[provider] = .unavailable(reason)
                case .invalidResponse:
                    states[provider] = .unavailable("Provider returned an unsupported response.")
                case .rateLimited:
                    states[provider] = .unavailable("Provider rate limit reached.")
                }
            }
        } catch {
            guard enabled.contains(provider) else { return }
            recordFailure(provider)
            if let cached = try? cache.load(provider) {
                states[provider] = .available(cached, .stale)
            } else {
                states[provider] = .unavailable("Usage is temporarily unavailable.")
            }
        }
    }

    private func shouldRefresh(
        _ provider: AgentProvider,
        reason: AllowanceRefreshReason
    ) -> Bool {
        guard let lastAttempt = lastAttempt[provider] else { return true }
        if let retryAfter = retryAfter[provider], now() < retryAfter { return false }
        let age = now().timeIntervalSince(lastAttempt)
        switch reason {
        case .manual, .enabled, .turnCompleted:
            return true
        case .working:
            return age >= AllowanceRefreshPolicy.workingInterval
        case .popoverOpened:
            return age >= AllowanceRefreshPolicy.popoverMaximumAge
        case .idle:
            return age >= AllowanceRefreshPolicy.idleInterval
        }
    }

    private func recordFailure(
        _ provider: AgentProvider,
        retryDelay: TimeInterval? = nil
    ) {
        let count = min((failureCount[provider] ?? 0) + 1, 6)
        failureCount[provider] = count
        let exponential = min(300, 5 * pow(2, Double(count - 1))) + max(0, jitter())
        let delay = max(exponential, retryDelay ?? 0)
        retryAfter[provider] = now().addingTimeInterval(delay)
    }

}

private extension AllowanceAdapterError {
    var retryDelay: TimeInterval? {
        if case let .rateLimited(retryAfter) = self { return retryAfter }
        return nil
    }
}
