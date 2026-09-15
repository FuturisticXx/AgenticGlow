import XCTest
@testable import AgenticGlowCore

final class CodexWindowScriptTests: XCTestCase {
    func testEscapeLeavesPlainTextUnchanged() {
        XCTAssertEqual(CodexWindowScript.escape("AgenticGlow"), "AgenticGlow")
    }

    func testEscapeHandlesDoubleQuotes() {
        XCTAssertEqual(
            CodexWindowScript.escape(#"my "project""#),
            #"my \"project\""#
        )
    }

    func testEscapeHandlesBackslashes() {
        XCTAssertEqual(
            CodexWindowScript.escape(#"a\b"#),
            #"a\\b"#
        )
    }

    func testEscapeHandlesBackslashesBeforeQuotesInOneScan() {
        // Backslashes must be escaped before quotes so an injected quote's
        // own escaping backslash isn't double-escaped by a second pass.
        XCTAssertEqual(
            CodexWindowScript.escape(#"end quote" then do shell script "rm -rf ~"#),
            #"end quote\" then do shell script \"rm -rf ~"#
        )
    }

    func testSourceEmbedsBundleIdentifier() {
        let source = CodexWindowScript.source(projectName: "AgenticGlow")
        XCTAssertTrue(source.contains(#"application id "com.openai.codex""#))
    }

    func testSourceEmbedsEscapedProjectName() {
        let source = CodexWindowScript.source(projectName: #"my "project""#)
        XCTAssertTrue(source.contains(#"my \"project\""#))
        XCTAssertFalse(source.contains(#"name contains "my "project""""#))
    }

    func testSourceActivatesBeforeReordering() {
        let source = CodexWindowScript.source(projectName: "AgenticGlow")
        let activateRange = source.range(of: "activate")
        let reorderRange = source.range(of: "set index")
        XCTAssertNotNil(activateRange)
        XCTAssertNotNil(reorderRange)
        XCTAssertTrue(activateRange!.lowerBound < reorderRange!.lowerBound)
    }
}
