import XCTest

@MainActor
final class AgenticGlowUITests: XCTestCase {
    func testPermissionSessionAppearsFirstAndIsAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "permission", "--ui-test-open-popover"]
        app.launch()

        let statusItem = app.statusItems["AgenticGlow.StatusItem"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        XCTAssertTrue(app.windows["AgenticGlow"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["AgenticGlow.SessionSummary"].waitForExistence(timeout: 3))
        XCTAssertEqual(
            app.staticTexts["AgenticGlow.SessionSummary"].value as? String,
            "1 agent needs you"
        )
        XCTAssertTrue(app.buttons["Claude, Example, Awaiting permission, Desktop"].exists)
        XCTAssertTrue(app.staticTexts["Usage access is off"].exists)
        XCTAssertTrue(app.buttons["Enable usage access"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["AgenticGlow.More"].exists)
        XCTAssertFalse(app.buttons["AgenticGlow.Integrations"].exists)
    }

    func testUsageConsentExplainsPrivacyBoundaryAndProviderChoices() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "empty", "--ui-test-open-popover"]
        app.launch()
        XCTAssertTrue(app.windows["AgenticGlow"].waitForExistence(timeout: 3))

        app.buttons["Enable usage access"].click()

        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Requests go only to providers you select."].exists)
        XCTAssertTrue(app.checkBoxes["OpenAI Codex"].exists)
        XCTAssertTrue(app.checkBoxes["Anthropic Claude"].exists)
        app.checkBoxes["Anthropic Claude"].click()
        XCTAssertTrue(app.secureTextFields["Claude session cookie"].exists)
        XCTAssertTrue(app.staticTexts["Unofficial Claude connection"].exists)
        XCTAssertTrue(app.buttons["Enable Usage"].exists)
        XCTAssertTrue(app.buttons["Not Now"].exists)
    }

    func testEmptyStateExplainsHowToStart() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "empty", "--ui-test-open-popover"]
        app.launch()
        XCTAssertTrue(app.statusItems["AgenticGlow.StatusItem"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.windows["AgenticGlow"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No active sessions"].waitForExistence(timeout: 3))
    }

    func testUnavailableProviderDoesNotHideSessionSurface() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-test-fixture", "allowance-unavailable", "--ui-test-open-popover"
        ]
        app.launch()

        XCTAssertTrue(app.windows["AgenticGlow"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No active sessions"].exists)
        XCTAssertTrue(app.staticTexts["Codex"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "AgenticGlow.Allowance.codex.Unavailable"
            ].waitForExistence(timeout: 3)
        )
    }

    func testSetupRepairChangesIntegrationState() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "setup-repair"]
        app.launch()

        let repair = app.buttons["Repair Codex"]
        XCTAssertTrue(repair.waitForExistence(timeout: 5))
        repair.click()
        XCTAssertTrue(app.staticTexts["Installed, trust required"].waitForExistence(timeout: 3))
    }

    func testSettingsExposeGlassClarityControl() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "empty", "--ui-test-open-popover"]
        app.launch()
        XCTAssertTrue(app.windows["AgenticGlow"].waitForExistence(timeout: 3))

        app.descendants(matching: .any)["AgenticGlow.More"].click()
        XCTAssertTrue(app.menuItems["Settings…"].waitForExistence(timeout: 2))
        app.menuItems["Settings…"].click()

        XCTAssertTrue(
            app.sliders["AgenticGlow.GlassClarity"].waitForExistence(timeout: 3)
        )
    }
}
