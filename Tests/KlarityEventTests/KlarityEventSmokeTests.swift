import XCTest
@testable import KlarityCore

final class KlarityEventSmokeTests: XCTestCase {
    func testHelperNameIsStable() {
        XCTAssertEqual(ProductMetadata.helperName, "klarity-event")
    }
}
