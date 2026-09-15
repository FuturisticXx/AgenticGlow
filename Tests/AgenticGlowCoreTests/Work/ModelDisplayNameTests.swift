import XCTest
@testable import AgenticGlowCore

final class ModelDisplayNameTests: XCTestCase {
    func testGrokVersionKeepsFamilyAndVersion() {
        XCTAssertEqual(ModelDisplayName.display("grok-4.6"), "Grok 4.6")
    }

    func testCursorPrefixedSlugDropsHarnessPrefix() {
        XCTAssertEqual(ModelDisplayName.display("cursor-grok-4.6-high"), "Grok 4.6")
        XCTAssertEqual(ModelDisplayName.display("cursor-grok-4.6-high-fast"), "Grok 4.6")
    }

    func testTierSuffixesAreOmitted() {
        XCTAssertEqual(ModelDisplayName.display("composer-2.5-fast"), "Composer 2.5")
        XCTAssertEqual(ModelDisplayName.display("claude-sonnet-5-thinking-high"), "Claude Sonnet 5")
    }

    func testAlreadyFriendlyNamesStayExact() {
        XCTAssertEqual(ModelDisplayName.display("Grok 4.6"), "Grok 4.6")
        XCTAssertEqual(ModelDisplayName.display("Claude Sonnet"), "Claude Sonnet")
        XCTAssertEqual(ModelDisplayName.display("Composer 2.5"), "Composer 2.5")
    }

    func testUnknownHyphenatedSlugTitleCasesWithoutInventingABrand() {
        XCTAssertEqual(ModelDisplayName.display("mystery-model-9"), "Mystery Model 9")
    }

    func testOpaqueUnparseableSlugStaysReadableWithoutAFakeProductName() {
        XCTAssertEqual(ModelDisplayName.display("other"), "other")
        XCTAssertEqual(ModelDisplayName.display("xyz123abc"), "xyz123abc")
    }

    func testEmptyAndNilStayAbsent() {
        XCTAssertNil(ModelDisplayName.display(Optional<String>.none))
        XCTAssertNil(ModelDisplayName.display(Optional("")))
        XCTAssertNil(ModelDisplayName.display(Optional("   ")))
    }

    func testDifferentFamiliesStayDistinct() {
        XCTAssertEqual(ModelDisplayName.display("grok-4.6"), "Grok 4.6")
        XCTAssertEqual(ModelDisplayName.display("composer-2.5"), "Composer 2.5")
        XCTAssertNotEqual(
            ModelDisplayName.display("grok-4.6"),
            ModelDisplayName.display("composer-2.5")
        )
    }
}
