import XCTest
@testable import AgenticGlow

final class DurationTierTests: XCTestCase {
    func testSecondsTierBelow60() {
        guard case .seconds(59) = DurationTier(seconds: 59) else {
            return XCTFail("expected .seconds(59)")
        }
    }

    func testMinutesTierAt60AndBelow3600() {
        guard case let .minutes(m, s) = DurationTier(seconds: 3_599) else {
            return XCTFail("expected .minutes")
        }
        XCTAssertEqual(m, 59)
        XCTAssertEqual(s, 59)
    }

    func testHoursTierAt3600() {
        guard case let .hours(h, m) = DurationTier(seconds: 3_665) else {
            return XCTFail("expected .hours")
        }
        XCTAssertEqual(h, 1)
        XCTAssertEqual(m, 1)
    }

    func testExactHourHasNoRemainderMinutes() {
        guard case let .hours(h, m) = DurationTier(seconds: 7_200) else {
            return XCTFail("expected .hours")
        }
        XCTAssertEqual(h, 2)
        XCTAssertEqual(m, 0)
    }

    func testNegativeSecondsClampToZero() {
        guard case .seconds(0) = DurationTier(seconds: -5) else {
            return XCTFail("expected .seconds(0)")
        }
    }
}
