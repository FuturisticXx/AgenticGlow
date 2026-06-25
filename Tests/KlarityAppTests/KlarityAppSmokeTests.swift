import XCTest
@testable import KlarityCore

final class KlarityAppSmokeTests: XCTestCase {
    func testAppBundleIdentifierIsStable() {
        XCTAssertEqual(ProductMetadata.bundleIdentifier, "com.twodamax.klarity")
    }
}
