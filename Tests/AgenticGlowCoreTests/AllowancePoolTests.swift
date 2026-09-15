import Foundation
import XCTest
@testable import AgenticGlowCore

/// Domain behavior for providers that report named sub-pools, and the
/// compatibility guarantees that let older cached data keep working.
final class AllowancePoolTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testAllowanceCachedBeforePoolsExistedStillDecodes() throws {
        let legacy = Data("""
        {
          "provider": "codex",
          "currentWindowLabel": "5h",
          "currentPercentUsed": 40,
          "currentPercentLeft": 60,
          "weeklyPercentUsed": 20,
          "weeklyPercentLeft": 80,
          "fetchedAt": 781000000
        }
        """.utf8)

        let allowance = try JSONDecoder().decode(ProviderAllowance.self, from: legacy)

        XCTAssertEqual(allowance.provider, .codex)
        XCTAssertEqual(allowance.currentPercentLeft, 60)
        XCTAssertTrue(allowance.pools.isEmpty)
    }

    func testPoolAllowanceSurvivesAnEncodeDecodeRoundTrip() throws {
        let allowance = cursorAllowance(cursorModels: 30, otherModels: 95)

        let data = try JSONEncoder().encode(allowance)
        let decoded = try JSONDecoder().decode(ProviderAllowance.self, from: data)

        XCTAssertEqual(decoded, allowance)
        XCTAssertEqual(decoded.pools.map(\.id), ["cursorModels", "otherModels"])
    }

    func testEachPoolGetsItsOwnHealthState() {
        let allowance = cursorAllowance(cursorModels: 25, otherModels: 94)

        let low = AllowanceWarning.lowWindows(in: allowance)

        XCTAssertEqual(low.map(\.label), ["Other Models"])
        XCTAssertEqual(low.first?.percentLeft, 6)
    }

    func testAHealthyPoolNeverMasksAConstrainedOne() {
        let allowance = cursorAllowance(cursorModels: 1, otherModels: 100)

        XCTAssertEqual(
            AllowanceWarning.lowWindows(in: allowance).map(\.label),
            ["Other Models"]
        )
    }

    func testPoolWithoutAValueIsNotTreatedAsExhausted() {
        let allowance = cursorAllowance(cursorModels: nil, otherModels: 50)

        let windows = AllowanceWarning.windows(in: allowance)

        XCTAssertEqual(windows.map(\.label), ["Other Models"])
        XCTAssertTrue(AllowanceWarning.lowWindows(in: allowance).isEmpty)
    }

    func testWindowProvidersAreUnaffectedByThePoolProjection() {
        let claude = ProviderAllowance(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentUsed: 95,
            currentResetAt: now,
            weeklyPercentUsed: 10,
            weeklyResetAt: now,
            fetchedAt: now
        )

        XCTAssertEqual(
            AllowanceWarning.windows(in: claude).map(\.label),
            ["5h", "week"]
        )
        XCTAssertEqual(AllowanceWarning.lowWindows(in: claude).map(\.label), ["5h"])
    }

    func testContinuationNamesTheConstrainedPoolRatherThanTheProvider() {
        let line = AllowanceContinuation.line(
            allowances: [.cursor: cursorAllowance(cursorModels: 26, otherModels: 94)]
        )

        XCTAssertEqual(line, "Cursor · Other Models 6% left")
    }

    func testContinuationStaysSilentWhenBothPoolsAreHealthy() {
        XCTAssertNil(
            AllowanceContinuation.line(
                allowances: [.cursor: cursorAllowance(cursorModels: 20, otherModels: 30)]
            )
        )
    }

    func testDifferingPoolResetsAreEachPreserved() {
        let later = now.addingTimeInterval(86_400)
        let allowance = ProviderAllowance(
            provider: .cursor,
            currentWindowLabel: "Billing cycle",
            currentPercentUsed: nil,
            currentResetAt: nil,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            pools: [
                AllowancePool(id: "cursorModels", label: "Cursor Models", percentUsed: 95, resetAt: now),
                AllowancePool(id: "otherModels", label: "Other Models", percentUsed: 95, resetAt: later)
            ],
            fetchedAt: now
        )

        let low = AllowanceWarning.lowWindows(in: allowance)

        XCTAssertEqual(low.map(\.resetAt), [now, later])
    }

    private func cursorAllowance(
        cursorModels: Double?,
        otherModels: Double?
    ) -> ProviderAllowance {
        ProviderAllowance(
            provider: .cursor,
            currentWindowLabel: "Billing cycle",
            currentPercentUsed: nil,
            currentResetAt: nil,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            pools: [
                AllowancePool(
                    id: "cursorModels",
                    label: "Cursor Models",
                    percentUsed: cursorModels,
                    resetAt: now
                ),
                AllowancePool(
                    id: "otherModels",
                    label: "Other Models",
                    percentUsed: otherModels,
                    resetAt: now
                )
            ],
            fetchedAt: now
        )
    }
}
