import Foundation

/// Opt-in provider status checks. Refreshes only when asked (popover open),
/// keeps results in memory only, and reports nil whenever health is unknown
/// so failures never become UI noise.
public actor ProviderStatusMonitor {
    private let requester: any ProviderStatusRequesting
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date
    private var enabled = false
    private var statuses: [AgentProvider: ProviderServiceStatus] = [:]
    private var lastFetch: [AgentProvider: Date] = [:]

    public init(
        requester: any ProviderStatusRequesting = StatusPageClient(),
        ttl: TimeInterval = 600,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.requester = requester
        self.ttl = ttl
        self.now = now
    }

    public func setEnabled(_ value: Bool) {
        enabled = value
        if !value {
            statuses = [:]
            lastFetch = [:]
        }
    }

    public func refreshIfStale() async {
        guard enabled else { return }
        for provider in AgentProvider.allCases {
            if let fetched = lastFetch[provider], now().timeIntervalSince(fetched) < ttl {
                continue
            }
            lastFetch[provider] = now()
            do {
                let data = try await requester.fetchStatus(for: provider)
                statuses[provider] = try StatusPageNormalizer.normalize(data)
            } catch {
                statuses[provider] = nil
            }
        }
    }

    public func status(for provider: AgentProvider) -> ProviderServiceStatus? {
        statuses[provider]
    }
}
