import XCTest
@testable import AgenticGlowCore

final class AgenticGlowEventSmokeTests: XCTestCase {
    func testHelperNameIsStable() {
        XCTAssertEqual(ProductMetadata.helperName, "agenticglow-event")
    }
}
