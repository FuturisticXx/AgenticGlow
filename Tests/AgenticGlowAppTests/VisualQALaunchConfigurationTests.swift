import XCTest
@testable import AgenticGlow

final class VisualQALaunchConfigurationTests: XCTestCase {
    func testReturnsNilOutsideVisualQAMode() {
        XCTAssertNil(VisualQALaunchConfiguration(
            arguments: ["AgenticGlow"],
            environment: [:]
        ))
    }

    func testParsesExplicitAppearanceAndClarity() {
        let configuration = VisualQALaunchConfiguration(arguments: [
            "AgenticGlow",
            "--visual-qa",
            "--visual-qa-appearance", "light",
            "--visual-qa-glass-clarity", "0.75"
        ])

        XCTAssertEqual(configuration?.appearance, .light)
        XCTAssertEqual(configuration?.glassClarity, 0.75)
        XCTAssertEqual(configuration?.opensPopover, true)
    }

    func testUsesSafeDefaultsAndClampsClarity() {
        let defaults = VisualQALaunchConfiguration(arguments: [
            "AgenticGlow", "--visual-qa"
        ])
        let aboveRange = VisualQALaunchConfiguration(arguments: [
            "AgenticGlow", "--visual-qa", "--visual-qa-glass-clarity", "2"
        ])

        XCTAssertEqual(defaults?.appearance, .dark)
        XCTAssertEqual(defaults?.glassClarity, 0)
        XCTAssertEqual(aboveRange?.glassClarity, 1)
    }

    func testEnvironmentEnablesIsolationWithoutOpeningPopover() {
        let configuration = VisualQALaunchConfiguration(
            arguments: ["AgenticGlow"],
            environment: ["AGENTICGLOW_ISOLATED_TEST_MODE": "1"]
        )

        XCTAssertEqual(configuration?.appearance, .dark)
        XCTAssertEqual(configuration?.glassClarity, 0)
        XCTAssertEqual(configuration?.opensPopover, false)
    }
}
