import XCTest
@testable import AgenticGlow

final class PermissionDissolveTests: XCTestCase {
    func testWorkingDwellShowsOnlyTheHexagon() {
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 0), 1)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 3), 1)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 5.99), 1)
    }

    func testPermissionDwellShowsOnlyTheExclamation() {
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 7), 0)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 8.5), 0)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 9.99), 0)
    }

    func testFadesCrossAtTheirMidpoints() {
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 6.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 10.5), 0.5, accuracy: 0.0001)
    }

    func testFadeOutFallsAndFadeInRises() {
        XCTAssertGreaterThan(
            PermissionDissolve.workingOpacity(at: 6.25),
            PermissionDissolve.workingOpacity(at: 6.75)
        )
        XCTAssertLessThan(
            PermissionDissolve.workingOpacity(at: 10.25),
            PermissionDissolve.workingOpacity(at: 10.75)
        )
    }

    func testCycleRepeatsEveryElevenSeconds() {
        XCTAssertEqual(PermissionDissolve.cycle, 11)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 11), 1)
        XCTAssertEqual(
            PermissionDissolve.workingOpacity(at: 17.5),
            PermissionDissolve.workingOpacity(at: 6.5),
            accuracy: 0.0001
        )
    }

    func testSweepIsBlueAtBothEndsOfTheWorkingDwell() {
        XCTAssertEqual(PermissionDissolve.sweepBlueShare(at: 0), 1, accuracy: 0.0001)
        XCTAssertEqual(PermissionDissolve.sweepBlueShare(at: 6), 1, accuracy: 0.0001)
    }

    func testSweepPeaksOrangeAtTheCenterOfTheWorkingDwell() {
        XCTAssertEqual(PermissionDissolve.sweepBlueShare(at: 3), 0, accuracy: 0.0001)
        XCTAssertEqual(PermissionDissolve.sweepBlueShare(at: 1.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PermissionDissolve.sweepBlueShare(at: 4.5), 0.5, accuracy: 0.0001)
    }

    func testSweepStaysBlueWhileTheHexagonIsHiddenOrFading() {
        XCTAssertEqual(PermissionDissolve.sweepBlueShare(at: 6.5), 1)
        XCTAssertEqual(PermissionDissolve.sweepBlueShare(at: 8.5), 1)
        XCTAssertEqual(PermissionDissolve.sweepBlueShare(at: 10.5), 1)
    }

    func testSweepRepeatsWithTheDissolveCycle() {
        XCTAssertEqual(
            PermissionDissolve.sweepBlueShare(at: 14),
            PermissionDissolve.sweepBlueShare(at: 3),
            accuracy: 0.0001
        )
    }
}
