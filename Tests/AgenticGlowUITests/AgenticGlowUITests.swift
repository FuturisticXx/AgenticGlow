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
        XCTAssertTrue(app.buttons["Claude, Example, Awaiting permission, Desktop"].exists)
    }

    func testEmptyStateExplainsHowToStart() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "empty", "--ui-test-open-popover"]
        app.launch()
        XCTAssertTrue(app.statusItems["AgenticGlow.StatusItem"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.windows["AgenticGlow"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No active sessions"].waitForExistence(timeout: 3))
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
}
