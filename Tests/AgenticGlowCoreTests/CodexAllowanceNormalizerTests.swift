import XCTest
@testable import AgenticGlowCore

final class CodexAllowanceNormalizerTests: XCTestCase {
    func testFiveHourPrimaryWindowLabelsAs5h() throws {
        let allowance = try normalize(primaryMinutes: 300, hasSecondary: true)
        XCTAssertEqual(allowance.currentWindowLabel, "5h")
    }

    /// Live-observed shape (2026-07-16, a ChatGPT Plus account): when the
    /// account has no separate 5-hour reading available, Codex reports its
    /// weekly (10,080 minute) limit as `primary` with `secondary: null`,
    /// rather than the usual 5h-primary + weekly-secondary pair.
    func testWeeklyScalePrimaryWindowLabelsAsWeekly() throws {
        let allowance = try normalize(primaryMinutes: 10_080, hasSecondary: false)
        XCTAssertEqual(allowance.currentWindowLabel, "Weekly")
        XCTAssertNil(allowance.weeklyPercentUsed)
    }

    func testUnrecognizedWindowDurationFallsBackToCurrent() throws {
        let allowance = try normalize(primaryMinutes: 60, hasSecondary: true)
        XCTAssertEqual(allowance.currentWindowLabel, "Current")
    }

    private func normalize(primaryMinutes: Int, hasSecondary: Bool) throws -> ProviderAllowance {
        let secondary = hasSecondary
            ? "\"secondary\":{\"usedPercent\":18,\"windowDurationMins\":10080,\"resetsAt\":1784805383}"
            : "\"secondary\":null"
        let json = """
        {"result":{"rateLimits":{"primary":{"usedPercent":97,"windowDurationMins":\(primaryMinutes),"resetsAt":1784805383},\(secondary)}}}
        """
        return try CodexAllowanceNormalizer.normalize(
            Data(json.utf8),
            fetchedAt: Date(timeIntervalSince1970: 1_783_099_000)
        )
    }
}
