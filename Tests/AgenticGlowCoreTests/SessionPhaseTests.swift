import XCTest
@testable import AgenticGlowCore

final class SessionPhaseTests: XCTestCase {
    func testIsActiveTrueForThinkingAndUsingTool() {
        XCTAssertTrue(SessionPhase.thinking.isActive)
        XCTAssertTrue(SessionPhase.usingTool.isActive)
    }

    func testIsActiveFalseForEveryOtherPhase() {
        for phase in [SessionPhase.idle, .permission, .completed, .disconnected, .failed] {
            XCTAssertFalse(phase.isActive, "\(phase) should not be active")
        }
    }
}
