import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

@MainActor
final class CursorUsagePresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    // MARK: - Preference

    func testCursorUsageDefaultsOffAndPersists() {
        let suiteName = "CursorUsagePresentationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)

        XCTAssertFalse(preferences.cursorUsageEnabled)

        preferences.cursorUsageEnabled = true

        XCTAssertTrue(defaults.bool(forKey: "cursorUsageEnabled"))
        XCTAssertTrue(PreferencesStore(defaults: defaults).cursorUsageEnabled)
    }

    func testCursorUsageDoesNotDisturbOtherProviderPreferences() {
        let suiteName = "CursorUsagePresentationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.codexUsageEnabled = true
        preferences.claudeUsageEnabled = true

        preferences.cursorUsageEnabled = true
        preferences.cursorUsageEnabled = false

        XCTAssertTrue(preferences.codexUsageEnabled)
        XCTAssertTrue(preferences.claudeUsageEnabled)
    }

    // MARK: - Popover presentation

    func testBothPoolsAreShownInOrderWithTheirOwnPercentages() {
        let presentation = AllowancePoolPresentation(
            allowance: cursorAllowance(cursorModels: 26, otherModels: 94),
            now: now
        )

        XCTAssertEqual(presentation.pools.map(\.label), ["Cursor Models", "Other Models"])
        XCTAssertEqual(presentation.pools.map(\.leftPercent), ["74", "6"])
    }

    func testOnlyTheConstrainedPoolIsMarkedLow() {
        let presentation = AllowancePoolPresentation(
            allowance: cursorAllowance(cursorModels: 26, otherModels: 94),
            now: now
        )

        XCTAssertFalse(presentation.pools[0].isLow)
        XCTAssertTrue(presentation.pools[1].isLow)
    }

    func testAMissingPoolReadsAsUnavailableNotAsEmpty() {
        let presentation = AllowancePoolPresentation(
            allowance: cursorAllowance(cursorModels: nil, otherModels: 20),
            now: now
        )

        XCTAssertNil(presentation.pools[0].leftPercent)
        XCTAssertTrue(presentation.pools[0].accessibility.contains("unavailable"))
        XCTAssertEqual(presentation.pools[1].leftPercent, "80")
    }

    func testASharedResetIsStatedOnceRatherThanOnEachPool() {
        let presentation = AllowancePoolPresentation(
            allowance: cursorAllowance(cursorModels: 26, otherModels: 40),
            now: now
        )

        XCTAssertNotNil(presentation.sharedResetValue)
        XCTAssertTrue(presentation.pools.allSatisfy { $0.resetValue == nil })
    }

    func testDifferingResetsAreCarriedByEachPool() {
        let allowance = ProviderAllowance(
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
                    percentUsed: 26,
                    resetAt: now.addingTimeInterval(3600)
                ),
                AllowancePool(
                    id: "otherModels",
                    label: "Other Models",
                    percentUsed: 40,
                    resetAt: now.addingTimeInterval(86_400 * 5)
                )
            ],
            fetchedAt: now
        )

        let presentation = AllowancePoolPresentation(allowance: allowance, now: now)

        XCTAssertNil(presentation.sharedResetValue)
        XCTAssertNotNil(presentation.pools[0].resetValue)
        XCTAssertNotNil(presentation.pools[1].resetValue)
    }

    func testAccessibilityNamesTheProviderAndThePool() {
        let presentation = AllowancePoolPresentation(
            allowance: cursorAllowance(cursorModels: 26, otherModels: 94),
            now: now
        )

        XCTAssertTrue(presentation.pools[1].accessibility.hasPrefix("Cursor, Other Models, 6 percent left"))
        XCTAssertTrue(presentation.pools[1].accessibility.hasSuffix("low"))
    }

    /// Codex and Claude keep the window presentation untouched.
    func testWindowProvidersStillUseTheExistingPresentation() {
        let claude = ProviderAllowance(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentUsed: 36,
            currentResetAt: now.addingTimeInterval(3600),
            weeklyPercentUsed: 47,
            weeklyResetAt: now.addingTimeInterval(86_400),
            fetchedAt: now
        )

        let presentation = AllowancePresentation(allowance: claude, now: now)

        XCTAssertEqual(presentation.currentValue, "64% left · 36% used")
        XCTAssertTrue(claude.pools.isEmpty)
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
                    resetAt: now.addingTimeInterval(86_400 * 9)
                ),
                AllowancePool(
                    id: "otherModels",
                    label: "Other Models",
                    percentUsed: otherModels,
                    resetAt: now.addingTimeInterval(86_400 * 9)
                )
            ],
            fetchedAt: now
        )
    }
}
