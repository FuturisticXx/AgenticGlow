import XCTest
@testable import AgenticGlow

final class VisualQALaunchConfigurationTests: XCTestCase {
    func testReturnsNilOutsideVisualQAMode() {
        XCTAssertNil(VisualQALaunchConfiguration(arguments: ["AgenticGlow"]))
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
}
