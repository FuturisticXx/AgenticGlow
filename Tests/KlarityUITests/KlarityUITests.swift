import XCTest

@MainActor
final class KlarityUITests: XCTestCase {
    func testPermissionSessionAppearsFirstAndIsAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "permission"]
        app.launch()

        let statusItem = app.statusItems["Klarity.StatusItem"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        XCTAssertTrue(app.staticTexts["Klarity.SessionSummary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Example, Awaiting permission, Desktop"].exists)
    }

    func testEmptyStateExplainsHowToStart() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "empty"]
        app.launch()
        app.statusItems["Klarity.StatusItem"].click()
        XCTAssertTrue(app.staticTexts["No active sessions"].exists)
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
