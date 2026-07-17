import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class SessionRowMotionTests: XCTestCase {
    func testPulsesWhileThinkingWithoutReduceMotion() {
        XCTAssertTrue(SessionRowMotion.shouldPulse(phase: .thinking, reduceMotion: false))
    }

    func testPulsesWhileUsingToolWithoutReduceMotion() {
        XCTAssertTrue(SessionRowMotion.shouldPulse(phase: .usingTool, reduceMotion: false))
    }

    func testNeverPulsesUnderReduceMotion() {
        for phase in [SessionPhase.idle, .thinking, .usingTool, .permission, .completed, .disconnected, .failed] {
            XCTAssertFalse(SessionRowMotion.shouldPulse(phase: phase, reduceMotion: true))
        }
    }

    func testDoesNotPulseForRestingPhases() {
        for phase in [SessionPhase.idle, .permission, .completed, .disconnected, .failed] {
            XCTAssertFalse(SessionRowMotion.shouldPulse(phase: phase, reduceMotion: false))
        }
    }
}
