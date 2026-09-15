import Foundation
import XCTest
@testable import AgenticGlowCore

final class AllowanceModelTests: XCTestCase {
    func testCodexNormalizationUsesLeftFirstDirectionAndResetDates() throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "codex-rate-limits",
                withExtension: "json"
            )
        )
        let data = try Data(contentsOf: url)
        let allowance = try CodexAllowanceNormalizer.normalize(
            data,
            fetchedAt: Date(timeIntervalSince1970: 1_783_099_000)
        )

        XCTAssertEqual(allowance.provider, .codex)
        XCTAssertEqual(allowance.currentWindowLabel, "5h")
        XCTAssertEqual(allowance.currentPercentUsed, 26)
        XCTAssertEqual(allowance.currentPercentLeft, 74)
        XCTAssertEqual(allowance.weeklyPercentUsed, 18)
        XCTAssertEqual(allowance.weeklyPercentLeft, 82)
        XCTAssertEqual(allowance.currentResetAt, Date(timeIntervalSince1970: 1_783_101_600))
        XCTAssertEqual(allowance.weeklyResetAt, Date(timeIntervalSince1970: 1_783_616_400))
    }

    func testPercentagesClampAndMissingValuesStayMissing() {
        let allowance = ProviderAllowance(
            provider: .claude,
            currentWindowLabel: "Session",
            currentPercentUsed: 140,
            currentResetAt: nil,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )

        XCTAssertEqual(allowance.currentPercentUsed, 100)
        XCTAssertEqual(allowance.currentPercentLeft, 0)
        XCTAssertNil(allowance.weeklyPercentUsed)
        XCTAssertNil(allowance.weeklyPercentLeft)
    }
}
