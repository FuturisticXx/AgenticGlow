import XCTest

final class KlarityLaunchTests: XCTestCase {
    func testApplicationLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5)
            || app.wait(for: .runningBackground, timeout: 5))
    }
}
