import XCTest
@testable import KlarityCore

final class ProductMetadataTests: XCTestCase {
    func testProductConstantsMatchPublicIdentifiers() {
        XCTAssertEqual(ProductMetadata.displayName, "Klarity")
        XCTAssertEqual(ProductMetadata.bundleIdentifier, "com.twodamax.klarity")
        XCTAssertEqual(ProductMetadata.schemaVersion, 1)
    }
}
