import Foundation
import XCTest
@testable import AgenticGlowCore

final class AllowanceRefreshCoordinatorTests: XCTestCase {
    func testNoRequestBeforeOptInAndDisableClearsCache() async throws {
        let adapter = RecordingAllowanceAdapter(provider: .codex)
        let cache = InMemoryAllowanceCache()
        let coordinator = AllowanceRefreshCoordinator(adapters: [adapter], cache: cache)

        await coordinator.refresh(.manual)
        var requestCount = await adapter.requestCount
        XCTAssertEqual(requestCount, 0)

        await coordinator.setEnabled(true, provider: .codex)
        requestCount = await adapter.requestCount
        XCTAssertEqual(requestCount, 1)
        XCTAssertNotNil(try cache.load(.codex))

        await coordinator.setEnabled(false, provider: .codex)
        await coordinator.refresh(.manual)
        requestCount = await adapter.requestCount
        XCTAssertEqual(requestCount, 1)
        XCTAssertNil(try cache.load(.codex))
        let state = await coordinator.state(for: .codex)
        XCTAssertEqual(state, .off)
    }

    func testDuplicateTriggersCoalesceToOneInFlightRequest() async {
        let adapter = RecordingAllowanceAdapter(provider: .codex, delay: 0.05)
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [adapter],
            cache: InMemoryAllowanceCache()
        )
        await coordinator.setEnabled(true, provider: .codex)

        async let first: Void = coordinator.refresh(.manual)
        async let second: Void = coordinator.refresh(.manual)
        _ = await (first, second)

        let count = await adapter.requestCount
        XCTAssertEqual(count, 2)
    }

    func testPopoverWorkingAndIdleCadenceUseApprovedMinimumIntervals() async {
        let clock = TestClock(now: 100)
        let adapter = RecordingAllowanceAdapter(provider: .codex)
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [adapter],
            cache: InMemoryAllowanceCache(),
            now: { clock.date }
        )
        await coordinator.setEnabled(true, provider: .codex)

        clock.now = 110
        await coordinator.refresh(.popoverOpened)
        clock.now = 116
        await coordinator.refresh(.popoverOpened)
        clock.now = 175
        await coordinator.refresh(.working)
        clock.now = 176
        await coordinator.refresh(.working)
        clock.now = 475
        await coordinator.refresh(.idle)
        clock.now = 476
        await coordinator.refresh(.idle)

        let count = await adapter.requestCount
        XCTAssertEqual(count, 4)
    }

    func testProviderErrorsApplyBackoffBeforeRetrying() async {
        let clock = TestClock(now: 100)
        let adapter = FailingAllowanceAdapter()
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [adapter],
            cache: InMemoryAllowanceCache(),
            now: { clock.date },
            jitter: { 0 }
        )
        await coordinator.setEnabled(true, provider: .codex)

        clock.now = 104
        await coordinator.refresh(.manual)
        var count = await adapter.requestCount
        XCTAssertEqual(count, 1)

        clock.now = 105
        await coordinator.refresh(.manual)
        count = await adapter.requestCount
        XCTAssertEqual(count, 2)
    }

    func testSuspensionStopsRefreshUntilNetworkAndWakeResume() async {
        let adapter = RecordingAllowanceAdapter(provider: .codex)
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [adapter],
            cache: InMemoryAllowanceCache()
        )
        await coordinator.setEnabled(true, provider: .codex)

        await coordinator.setSuspended(true)
        await coordinator.refresh(.manual)
        var count = await adapter.requestCount
        XCTAssertEqual(count, 1)

        await coordinator.setSuspended(false)
        await coordinator.refresh(.manual)
        count = await adapter.requestCount
        XCTAssertEqual(count, 2)
    }

    func testDisablingDuringRequestDiscardsResponseAndLeavesCacheEmpty() async throws {
        let adapter = RecordingAllowanceAdapter(provider: .codex, delay: 0.1)
        let cache = InMemoryAllowanceCache()
        let coordinator = AllowanceRefreshCoordinator(adapters: [adapter], cache: cache)

        let enabling = Task { await coordinator.setEnabled(true, provider: .codex) }
        try await Task.sleep(for: .milliseconds(10))
        await coordinator.setEnabled(false, provider: .codex)
        await enabling.value

        XCTAssertNil(try cache.load(.codex))
        let state = await coordinator.state(for: .codex)
        XCTAssertEqual(state, .off)
    }
}

private actor FailingAllowanceAdapter: AllowanceProviding {
    nonisolated let provider = AgentProvider.codex
    private(set) var requestCount = 0
    func fetch() async throws -> ProviderAllowance {
        requestCount += 1
        throw AllowanceAdapterError.unavailable("Offline")
    }
}

private actor RecordingAllowanceAdapter: AllowanceProviding {
    nonisolated let provider: AgentProvider
    private(set) var requestCount = 0
    private let delay: TimeInterval

    init(provider: AgentProvider, delay: TimeInterval = 0) {
        self.provider = provider
        self.delay = delay
    }

    func fetch() async throws -> ProviderAllowance {
        requestCount += 1
        if delay > 0 {
            try await Task.sleep(for: .seconds(delay))
        }
        return ProviderAllowance(
            provider: provider,
            currentWindowLabel: "5h",
            currentPercentUsed: 20,
            currentResetAt: nil,
            weeklyPercentUsed: 10,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
    }
}

private final class TestClock: @unchecked Sendable {
    var now: TimeInterval
    var date: Date { Date(timeIntervalSince1970: now) }
    init(now: TimeInterval) { self.now = now }
}

private final class InMemoryAllowanceCache: AllowanceCaching, @unchecked Sendable {
    private var values: [AgentProvider: ProviderAllowance] = [:]
    func save(_ allowance: ProviderAllowance) throws { values[allowance.provider] = allowance }
    func load(_ provider: AgentProvider) throws -> ProviderAllowance? { values[provider] }
    func remove(_ provider: AgentProvider) throws { values.removeValue(forKey: provider) }
}
