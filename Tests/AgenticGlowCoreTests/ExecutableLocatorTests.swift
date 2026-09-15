import XCTest
@testable import AgenticGlowCore

final class ExecutableLocatorTests: XCTestCase {
    func testCodexAppBinaryIsPreferredOverHomebrewNodeLauncher() throws {
        let candidates = ExecutableLocator.candidatePaths(
            for: "codex",
            homeDirectory: "/Users/example"
        )

        let chatGPTBinary = try XCTUnwrap(
            candidates.firstIndex(of: "/Applications/ChatGPT.app/Contents/Resources/codex")
        )
        let homebrewLauncher = try XCTUnwrap(
            candidates.firstIndex(of: "/opt/homebrew/bin/codex")
        )

        XCTAssertLessThan(chatGPTBinary, homebrewLauncher)
    }

    func testCursorAppBinaryIsPreferredOverHomebrew() {
        let candidates = ExecutableLocator.candidatePaths(
            for: "cursor",
            homeDirectory: "/Users/example"
        )

        XCTAssertEqual(
            candidates.first,
            "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
        )
        XCTAssertTrue(candidates.contains("/opt/homebrew/bin/cursor"))
    }
}
