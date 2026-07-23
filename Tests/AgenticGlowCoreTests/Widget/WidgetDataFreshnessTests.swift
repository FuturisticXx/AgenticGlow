import Foundation
import XCTest
@testable import AgenticGlowCore

final class WidgetDataFreshnessTests: XCTestCase {
    private let generatedAt = Date(timeIntervalSince1970: 1_783_099_000)

    func testWithinThresholdIsFresh() {
        let now = generatedAt.addingTimeInterval(WidgetDataFreshness.staleThreshold - 1)
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: generatedAt, now: now), .fresh)
    }

    func testAtThresholdIsFresh() {
        let now = generatedAt.addingTimeInterval(WidgetDataFreshness.staleThreshold)
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: generatedAt, now: now), .fresh)
    }

    func testBeyondThresholdIsStale() {
        let now = generatedAt.addingTimeInterval(WidgetDataFreshness.staleThreshold + 1)
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: generatedAt, now: now), .stale)
    }

    func testGeneratedInTheFutureIsFresh() {
        let now = generatedAt.addingTimeInterval(-60)
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: generatedAt, now: now), .fresh)
    }
}
