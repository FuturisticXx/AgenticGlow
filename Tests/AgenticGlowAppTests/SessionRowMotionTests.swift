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

    func testDetailMotionHasLegibleButFastTiming() {
        XCTAssertEqual(SessionRowMotion.detailToggleDuration(reduceMotion: false), 0.2)
        XCTAssertEqual(SessionRowMotion.detailOffset, -6)
    }

    func testReducedMotionKeepsShortOpacityFeedback() {
        XCTAssertEqual(SessionRowMotion.detailToggleDuration(reduceMotion: true), 0.12)
    }

    func testChevronRotationMatchesExpansionState() {
        XCTAssertEqual(SessionRowMotion.chevronRotation(isExpanded: false), 0)
        XCTAssertEqual(SessionRowMotion.chevronRotation(isExpanded: true), 180)
    }

    func testIconBounceTriggerTracksIconChanges() {
        XCTAssertEqual(SessionRowMotion.iconBounceTrigger(icon: "terminal", reduceMotion: false), "terminal")
        XCTAssertEqual(SessionRowMotion.iconBounceTrigger(icon: "pencil", reduceMotion: false), "pencil")
    }

    func testIconBounceTriggerIsConstantUnderReducedMotion() {
        XCTAssertEqual(SessionRowMotion.iconBounceTrigger(icon: "terminal", reduceMotion: true), "")
        XCTAssertEqual(SessionRowMotion.iconBounceTrigger(icon: "pencil", reduceMotion: true), "")
    }
}
