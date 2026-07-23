import Foundation
import XCTest

final class ReleasePackagingScriptTests: XCTestCase {
    func testReleaseBuildSignsWidgetWithItsEntitlementsBeforeContainingApp() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let script = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Scripts/build-release.sh"),
            encoding: .utf8
        )

        let widgetPath = "widget=\"$app/Contents/PlugIns/AgenticGlowWidget.appex\""
        let widgetEntitlements = "--entitlements Config/AgenticGlowWidget.entitlements"
        let widgetTarget = "\"$widget\""
        let appEntitlements = "--entitlements Config/AgenticGlow.entitlements"

        let widgetPathRange = try XCTUnwrap(script.range(of: widgetPath))
        let widgetEntitlementsRange = try XCTUnwrap(script.range(of: widgetEntitlements))
        let widgetTargetRange = try XCTUnwrap(script.range(of: widgetTarget))
        let appEntitlementsRange = try XCTUnwrap(script.range(of: appEntitlements))

        XCTAssertLessThan(widgetPathRange.lowerBound, widgetEntitlementsRange.lowerBound)
        XCTAssertLessThan(widgetEntitlementsRange.lowerBound, widgetTargetRange.lowerBound)
        XCTAssertLessThan(widgetTargetRange.lowerBound, appEntitlementsRange.lowerBound)
    }

    func testReleaseVerificationRequiresSignedUniversalWidgetWithSharedAppGroup() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let script = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Scripts/verify-release.sh"),
            encoding: .utf8
        )

        let requiredChecks = [
            "widget=\"$app/Contents/PlugIns/AgenticGlowWidget.appex\"",
            "test -d \"$widget\"",
            "lipo -archs \"$widget/Contents/MacOS/AgenticGlowWidget\"",
            "codesign --verify --strict --verbose=2 \"$widget\"",
            "codesign -d --entitlements :- \"$widget\"",
            "group.com.twodamax.agenticglow",
        ]

        for requiredCheck in requiredChecks {
            XCTAssertTrue(
                script.contains(requiredCheck),
                "Missing release widget check: \(requiredCheck)"
            )
        }
    }
}
