import XCTest
@testable import AgenticGlowCore

final class PosixPathTests: XCTestCase {
    func testComponentsIgnoreRepeatedAndTrailingSeparators() {
        XCTAssertEqual(PosixPath.components("//a///b//"), ["a", "b"])
    }

    func testDotIsDroppedAndDotDotAscends() {
        XCTAssertEqual(PosixPath.components("/a/./b/../c"), ["a", "c"])
    }

    func testAscendingPastRootClampsToRoot() {
        XCTAssertEqual(PosixPath.standardized("/../.."), "/")
        XCTAssertEqual(PosixPath.components("/a/../.."), [])
    }

    func testStandardizedKeepsAnAbsoluteLeadingSlashAndDropsATrailingOne() {
        XCTAssertEqual(PosixPath.standardized("/Users/me/project/"), "/Users/me/project")
        XCTAssertEqual(PosixPath.standardized("/"), "/")
    }

    func testLastComponentOfRootIsNil() {
        XCTAssertNil(PosixPath.lastComponent("/"))
        XCTAssertEqual(PosixPath.lastComponent("/a/b"), "b")
    }

    /// The regression this type exists for. `URL(fileURLWithPath:)`
    /// truncates at PATH_MAX on some Foundation versions, which made a deep
    /// path report a different last component on CI than locally. String
    /// splitting has no ceiling, so both agree.
    func testDeepPathIsNotTruncatedAtPathMax() {
        let deep = "/" + (0..<400).map { "level\($0)" }.joined(separator: "/")
        XCTAssertGreaterThan(deep.count, 1024)
        XCTAssertEqual(PosixPath.lastComponent(deep), "level399")
        XCTAssertEqual(PosixPath.standardized(deep), deep)
    }

    func testWorkIdentityNormalizesWithoutThatCeiling() {
        let deep = "/" + (0..<400).map { "level\($0)" }.joined(separator: "/")
        XCTAssertEqual(WorkIdentity.normalize(path: deep)?.value, deep)
    }
}
