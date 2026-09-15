import Foundation
import XCTest
@testable import AgenticGlowCore

/// Cursor's behavior inside the shared refresh coordinator: off means no
/// requests at all, an expired credential reads as a credential problem
/// rather than an exhausted allowance, and one provider's trouble never
/// touches another's.
final class CursorAllowanceProviderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testCursorUsageOffMakesNoRequestsAndShowsNothing() async {
        let cursor = ScriptedAllowanceAdapter(provider: .cursor, result: .success(cursorAllowance()))
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [cursor],
            cache: InMemoryCache()
        )

        await coordinator.refresh(.manual)
        await coordinator.refresh(.popoverOpened)

        let count = await cursor.requestCount
        XCTAssertEqual(count, 0)
        let state = await coordinator.state(for: .cursor)
        XCTAssertEqual(state, .off)
    }

    func testEnablingCursorFetchesAndPublishesBothPools() async {
        let cursor = ScriptedAllowanceAdapter(provider: .cursor, result: .success(cursorAllowance()))
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [cursor],
            cache: InMemoryCache()
        )

        await coordinator.setEnabled(true, provider: .cursor)

        guard case let .available(allowance, freshness) = await coordinator.state(for: .cursor) else {
            return XCTFail("Expected an available Cursor allowance")
        }
        XCTAssertEqual(freshness, .fresh)
        XCTAssertEqual(allowance.pools.map(\.label), ["Cursor Models", "Other Models"])
    }

    func testDisablingCursorStopsRequestsAndClearsTheCache() async throws {
        let cursor = ScriptedAllowanceAdapter(provider: .cursor, result: .success(cursorAllowance()))
        let cache = InMemoryCache()
        let coordinator = AllowanceRefreshCoordinator(adapters: [cursor], cache: cache)

        await coordinator.setEnabled(true, provider: .cursor)
        XCTAssertNotNil(try cache.load(.cursor))

        await coordinator.setEnabled(false, provider: .cursor)
        await coordinator.refresh(.manual)

        let count = await cursor.requestCount
        XCTAssertEqual(count, 1, "No request may follow the provider being turned off")
        XCTAssertNil(try cache.load(.cursor))
        let state = await coordinator.state(for: .cursor)
        XCTAssertEqual(state, .off)
    }

    func testExpiredCredentialSurfacesAsUsageAccessNotZeroRemaining() async {
        let cursor = ScriptedAllowanceAdapter(
            provider: .cursor,
            result: .failure(
                .unavailable("Cursor session cookie expired. Update Usage Access.")
            )
        )
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [cursor],
            cache: InMemoryCache()
        )

        await coordinator.setEnabled(true, provider: .cursor)

        let state = await coordinator.state(for: .cursor)
        XCTAssertEqual(
            state,
            .unavailable("Cursor session cookie expired. Update Usage Access.")
        )
    }

    func testTransientFailureKeepsTheLastReadingAndMarksItStale() async {
        let cursor = ScriptedAllowanceAdapter(provider: .cursor, result: .success(cursorAllowance()))
        let coordinator = AllowanceRefreshCoordinator(adapters: [cursor], cache: InMemoryCache())

        await coordinator.setEnabled(true, provider: .cursor)
        await cursor.setResult(.failure(.unavailable("Cursor usage is temporarily unavailable.")))
        await coordinator.refresh(.manual)

        guard case let .available(allowance, freshness) = await coordinator.state(for: .cursor) else {
            return XCTFail("Expected the cached Cursor allowance to be kept")
        }
        XCTAssertEqual(freshness, .stale)
        XCTAssertEqual(allowance.pools.count, 2)
    }

    func testCursorFailureLeavesClaudeUnaffected() async {
        let cursor = ScriptedAllowanceAdapter(
            provider: .cursor,
            result: .failure(.unavailable("Cursor session cookie expired. Update Usage Access."))
        )
        let claude = ScriptedAllowanceAdapter(
            provider: .claude,
            result: .success(
                ProviderAllowance(
                    provider: .claude,
                    currentWindowLabel: "5h",
                    currentPercentUsed: 30,
                    currentResetAt: now,
                    weeklyPercentUsed: 10,
                    weeklyResetAt: now,
                    fetchedAt: now
                )
            )
        )
        let coordinator = AllowanceRefreshCoordinator(
            adapters: [cursor, claude],
            cache: InMemoryCache()
        )

        await coordinator.setEnabled(true, provider: .cursor)
        await coordinator.setEnabled(true, provider: .claude)

        guard case let .available(allowance, _) = await coordinator.state(for: .claude) else {
            return XCTFail("Claude must still resolve while Cursor is failing")
        }
        XCTAssertEqual(allowance.currentPercentLeft, 70)
        XCTAssertTrue(allowance.pools.isEmpty)
    }

    private func cursorAllowance() -> ProviderAllowance {
        ProviderAllowance(
            provider: .cursor,
            currentWindowLabel: "Billing cycle",
            currentPercentUsed: nil,
            currentResetAt: nil,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            pools: [
                AllowancePool(id: "cursorModels", label: "Cursor Models", percentUsed: 26, resetAt: now),
                AllowancePool(id: "otherModels", label: "Other Models", percentUsed: 94, resetAt: now)
            ],
            fetchedAt: now
        )
    }
}

private actor ScriptedAllowanceAdapter: AllowanceProviding {
    nonisolated let provider: AgentProvider
    private var result: Result<ProviderAllowance, AllowanceAdapterError>
    private(set) var requestCount = 0

    init(provider: AgentProvider, result: Result<ProviderAllowance, AllowanceAdapterError>) {
        self.provider = provider
        self.result = result
    }

    func setResult(_ result: Result<ProviderAllowance, AllowanceAdapterError>) {
        self.result = result
    }

    func fetch() async throws -> ProviderAllowance {
        requestCount += 1
        return try result.get()
    }
}

private final class InMemoryCache: AllowanceCaching, @unchecked Sendable {
    private var values: [AgentProvider: ProviderAllowance] = [:]
    func save(_ allowance: ProviderAllowance) throws { values[allowance.provider] = allowance }
    func load(_ provider: AgentProvider) throws -> ProviderAllowance? { values[provider] }
    func remove(_ provider: AgentProvider) throws { values.removeValue(forKey: provider) }
}
