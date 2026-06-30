import XCTest

@MainActor
final class KlarityUITests: XCTestCase {
    func testPermissionSessionAppearsFirstAndIsAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "permission", "--ui-test-open-popover"]
        app.launch()

        let statusItem = app.statusItems["Klarity.StatusItem"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        XCTAssertTrue(app.windows["Klarity"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Klarity.SessionSummary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Claude, Example, Awaiting permission, Desktop"].exists)
    }

    func testEmptyStateExplainsHowToStart() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "empty", "--ui-test-open-popover"]
        app.launch()
        XCTAssertTrue(app.statusItems["Klarity.StatusItem"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.windows["Klarity"].waitForExistence(timeout: 3))
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
