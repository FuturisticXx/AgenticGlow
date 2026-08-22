import XCTest
@testable import AgenticGlowCore

final class WorkIdentityTests: XCTestCase {
    func testSamePathNormalizesToSameValue() {
        let a = WorkIdentity.normalize(path: "/Volumes/Liquid/2DaMax Development/AgenticGlow")
        let b = WorkIdentity.normalize(path: "/Volumes/Liquid/2DaMax Development/AgenticGlow")
        XCTAssertEqual(a?.value, b?.value)
        XCTAssertEqual(a?.rawPath, "/Volumes/Liquid/2DaMax Development/AgenticGlow")
    }

    func testTrailingSlashAndDotSegmentsStillGroup() {
        let clean = WorkIdentity.normalize(path: "/tmp/AgenticGlow")
        let slash = WorkIdentity.normalize(path: "/tmp/AgenticGlow/")
        let dotted = WorkIdentity.normalize(path: "/tmp/AgenticGlow/./")
        let parent = WorkIdentity.normalize(path: "/tmp/AgenticGlow/../AgenticGlow")
        XCTAssertEqual(clean?.value, "/tmp/AgenticGlow")
        XCTAssertEqual(slash?.value, clean?.value)
        XCTAssertEqual(dotted?.value, clean?.value)
        XCTAssertEqual(parent?.value, clean?.value)
    }

    func testExtraSlashesCollapse() {
        let identity = WorkIdentity.normalize(path: "/tmp//AgenticGlow")
        XCTAssertEqual(identity?.value, "/tmp/AgenticGlow")
    }

    func testDoesNotLowercase() {
        let identity = WorkIdentity.normalize(path: "/tmp/AgenticGlow")
        XCTAssertEqual(identity?.value, "/tmp/AgenticGlow")
        XCTAssertNotEqual(identity?.value, "/tmp/agenticglow")
    }

    func testRootPathStaysRoot() {
        XCTAssertEqual(WorkIdentity.normalize(path: "/")?.value, "/")
    }

    func testRejectsEmptyNulAndRelative() {
        XCTAssertNil(WorkIdentity.normalize(path: ""))
        XCTAssertNil(WorkIdentity.normalize(path: "AgenticGlow"))
        XCTAssertNil(WorkIdentity.normalize(path: "/tmp/foo\0bar"))
    }

    func testDoesNotRequireTheFolderToExist() {
        let path = "/Volumes/MissingVolume/DeletedProject"
        let identity = WorkIdentity.normalize(path: path)
        XCTAssertEqual(identity?.value, path)
    }

    func testDoesNotResolveSymlinks() {
        // standardizedFileURL collapses spelling; it does not follow
        // /tmp onto /private/tmp. Those stay different identities.
        let tmp = WorkIdentity.normalize(path: "/tmp/AgenticGlow")
        let privateTmp = WorkIdentity.normalize(path: "/private/tmp/AgenticGlow")
        XCTAssertNotEqual(tmp?.value, privateTmp?.value)
    }
}
