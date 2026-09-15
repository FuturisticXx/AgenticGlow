import XCTest
@testable import AgenticGlowCore

final class ProductMetadataTests: XCTestCase {
    func testProductConstantsMatchPublicIdentifiers() {
        XCTAssertEqual(ProductMetadata.displayName, "AgenticGlow")
        XCTAssertEqual(ProductMetadata.bundleIdentifier, "com.twodamax.agenticglow")
        XCTAssertEqual(ProductMetadata.schemaVersion, 1)
    }
}
