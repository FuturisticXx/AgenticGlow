import XCTest
@testable import AgenticGlowCore

final class AgenticGlowAppSmokeTests: XCTestCase {
    func testAppBundleIdentifierIsStable() {
        XCTAssertEqual(ProductMetadata.bundleIdentifier, "com.twodamax.agenticglow")
    }
}
