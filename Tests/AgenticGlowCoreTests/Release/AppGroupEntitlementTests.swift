import Foundation
import XCTest
@testable import AgenticGlowCore

final class AppGroupEntitlementTests: XCTestCase {
    func testProductionAppGroupIdentifierIsConstant() {
        // Ensure the production App Group identifier is defined and constant
        let productionIdentifier = "Z52AX2BH7T.group.com.twodamax.agenticglow"
        XCTAssertEqual(
            AppGroupSnapshotSource.appGroupIdentifier,
            productionIdentifier,
            "Runtime App Group identifier must match production constant"
        )
    }

    func testAppGroupIdentifierFormat() {
        let identifier = AppGroupSnapshotSource.appGroupIdentifier

        // Must start with Team ID
        XCTAssertTrue(
            identifier.hasPrefix("Z52AX2BH7T."),
            "App Group must be Team-ID-prefixed for macOS non-sandboxed app + sandboxed widget"
        )

        // Must end with the group suffix
        XCTAssertTrue(
            identifier.hasSuffix(".group.com.twodamax.agenticglow"),
            "App Group must end with .group.com.twodamax.agenticglow"
        )

        // Must not contain variable syntax
        XCTAssertFalse(
            identifier.contains("$("),
            "App Group identifier must not contain build variable syntax"
        )

        // Must not be empty
        XCTAssertFalse(
            identifier.isEmpty,
            "App Group identifier must not be empty"
        )
    }

    func testAppGroupIdentifierRejectsBareGroupForm() {
        // The bare group.com.twodamax.agenticglow form was broken for
        // non-sandboxed app + sandboxed widget architecture (commit c8a3879)
        let bareForm = "group.com.twodamax.agenticglow"
        XCTAssertNotEqual(
            AppGroupSnapshotSource.appGroupIdentifier,
            bareForm,
            "Must not use bare group. form which was previously broken"
        )
    }

    func testAppGroupIdentifierRejectsUnresolvedVariable() {
        // $(APP_GROUP_ID) variable syntax indicates build configuration failure
        let unresolvedVariable = "$(APP_GROUP_ID)"
        XCTAssertNotEqual(
            AppGroupSnapshotSource.appGroupIdentifier,
            unresolvedVariable,
            "Must not contain unresolved build variable syntax"
        )
    }
}
