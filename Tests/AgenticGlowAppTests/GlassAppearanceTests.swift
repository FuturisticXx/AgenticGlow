import SwiftUI
import XCTest
@testable import AgenticGlow

final class GlassAppearanceTests: XCTestCase {
    func testZeroClarityExactlyMatchesCurrentSurface() {
        let dark = GlassAppearance(
            clarity: 0,
            colorScheme: .dark,
            reduceTransparency: false
        )
        let light = GlassAppearance(
            clarity: 0,
            colorScheme: .light,
            reduceTransparency: false
        )

        XCTAssertEqual(dark.scrimOpacity, 0.45)
        XCTAssertEqual(light.scrimOpacity, 0)
        XCTAssertEqual(dark.highlightOpacity, 0)
        XCTAssertEqual(dark.depthOpacity, 0)
        XCTAssertEqual(dark.specularOpacity, 0)
        XCTAssertEqual(light.highlightOpacity, 0)
        XCTAssertEqual(light.depthOpacity, 0)
        XCTAssertEqual(light.specularOpacity, 0)
    }

    func testMaximumClarityIsMoreTransmissiveAndDimensionalInBothAppearances() {
        let dark = GlassAppearance(
            clarity: 1,
            colorScheme: .dark,
            reduceTransparency: false
        )
        let light = GlassAppearance(
            clarity: 1,
            colorScheme: .light,
            reduceTransparency: false
        )

        XCTAssertEqual(dark.scrimOpacity, 0.16, accuracy: 0.0001)
        XCTAssertEqual(light.scrimOpacity, 0)
        XCTAssertEqual(dark.highlightOpacity, 0.16, accuracy: 0.0001)
        XCTAssertEqual(light.highlightOpacity, 0.24, accuracy: 0.0001)
        XCTAssertEqual(dark.depthOpacity, 0.10, accuracy: 0.0001)
        XCTAssertEqual(light.depthOpacity, 0.07, accuracy: 0.0001)
        XCTAssertEqual(dark.specularOpacity, 0.18, accuracy: 0.0001)
        XCTAssertEqual(light.specularOpacity, 0.28, accuracy: 0.0001)
    }

    func testClarityClampsBeforeDerivingLayers() {
        let belowRange = GlassAppearance(
            clarity: -1,
            colorScheme: .dark,
            reduceTransparency: false
        )
        let aboveRange = GlassAppearance(
            clarity: 2,
            colorScheme: .dark,
            reduceTransparency: false
        )

        XCTAssertEqual(belowRange.clarity, 0)
        XCTAssertEqual(aboveRange.clarity, 1)
        XCTAssertEqual(belowRange.scrimOpacity, 0.45)
        XCTAssertEqual(aboveRange.scrimOpacity, 0.16, accuracy: 0.0001)
    }

    func testReduceTransparencyUsesLegibleBaselineRegardlessOfPreference() {
        let appearance = GlassAppearance(
            clarity: 1,
            colorScheme: .dark,
            reduceTransparency: true
        )

        XCTAssertEqual(appearance.clarity, 0)
        XCTAssertEqual(appearance.scrimOpacity, 0.45)
        XCTAssertEqual(appearance.highlightOpacity, 0)
        XCTAssertEqual(appearance.depthOpacity, 0)
        XCTAssertEqual(appearance.specularOpacity, 0)
    }
}
