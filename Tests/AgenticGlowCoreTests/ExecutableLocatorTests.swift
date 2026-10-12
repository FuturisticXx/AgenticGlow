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

    func testRelocatedAppBinaryIsPreferredOverTheOldLocation() throws {
        let candidates = ExecutableLocator.candidatePaths(for: "codex", homeDirectory: "/Users/example")
        let relocated = try XCTUnwrap(
            candidates.firstIndex(of: "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex")
        )
        let old = try XCTUnwrap(candidates.firstIndex(of: "/Applications/ChatGPT.app/Contents/Resources/codex"))
        let homebrew = try XCTUnwrap(candidates.firstIndex(of: "/opt/homebrew/bin/codex"))
        XCTAssertLessThan(relocated, old)
        XCTAssertLessThan(old, homebrew)
    }

    func testLaunchEnvironmentPutsTheLauncherDirectoryOnPath() {
        let environment = ExecutableLocator.launchEnvironment(
            for: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            base: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": "/Users/example"]
        )
        XCTAssertEqual(environment["PATH"], "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin")
        XCTAssertEqual(environment["HOME"], "/Users/example")
    }

    func testLaunchEnvironmentSuppliesASystemPathWhenNoneIsInherited() {
        let environment = ExecutableLocator.launchEnvironment(
            for: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            base: [:]
        )
        XCTAssertEqual(environment["PATH"], "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin")
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
