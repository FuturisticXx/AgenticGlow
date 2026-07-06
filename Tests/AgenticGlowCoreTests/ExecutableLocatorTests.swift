import XCTest
@testable import AgenticGlowCore

final class ExecutableLocatorTests: XCTestCase {
    func testCodexAppBinaryIsPreferredOverHomebrewNodeLauncher() throws {
        let candidates = ExecutableLocator.candidatePaths(
            for: "codex",
            homeDirectory: "/Users/example"
        )

        let appBinary = try XCTUnwrap(
            candidates.firstIndex(of: "/Applications/Codex.app/Contents/Resources/codex")
        )
        let homebrewLauncher = try XCTUnwrap(
            candidates.firstIndex(of: "/opt/homebrew/bin/codex")
        )

        XCTAssertLessThan(appBinary, homebrewLauncher)
    }
}
