import XCTest
@testable import AgenticGlowCore

final class CursorIntegrationManagerTests: XCTestCase {
    func testInstallCreatesNativeCursorHooksAndIsIdempotent() throws {
        let hooks = temporaryConfig(contents: """
        {"version":1,"hooks":{"afterFileEdit":[{"command":"existing-format.sh"}]}}
        """)
        let manager = CursorIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        try manager.install()
        try manager.install()

        let object = try integrationJSONObject(hooks)
        let text = String(
            decoding: try JSONSerialization.data(withJSONObject: object),
            as: UTF8.self
        )
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertTrue(text.contains("existing-format.sh"))
        XCTAssertEqual(
            text.components(separatedBy: "--agenticglow-hook").count - 1,
            HookEventKind.cursorEvents.count
        )
        XCTAssertTrue(text.contains("beforeSubmitPrompt"))
        XCTAssertTrue(text.contains("cursor UserPromptSubmit"))
        XCTAssertFalse(text.contains("\"UserPromptSubmit\""))
        XCTAssertTrue(try manager.status().installed)
        XCTAssertFalse(try manager.status().requiresTrustReview)
        XCTAssertNil(try manager.status().issue)
        XCTAssertEqual(try manager.status().installedEvents, HookEventKind.cursorEvents)
    }

    func testRemoveDeletesOnlyAgenticGlowHooks() throws {
        let hooks = temporaryConfig(contents: """
        {"version":1,"hooks":{
          "preToolUse":[
            {"command":"existing-policy.sh"},
            {"command":"'/tmp/agenticglow-event' cursor PreToolUse --agenticglow-hook","timeout":5}
          ]
        }}
        """)
        let manager = CursorIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        try manager.remove()

        let text = try String(contentsOf: hooks, encoding: .utf8)
        XCTAssertTrue(text.contains("existing-policy.sh"))
        XCTAssertFalse(text.contains("--agenticglow-hook"))
    }

    func testRepairReplacesStaleHelperPath() throws {
        let hooks = temporaryConfig(contents: """
        {"version":1,"hooks":{"sessionStart":[
          {"command":"'/old/agenticglow-event' cursor SessionStart --agenticglow-hook","timeout":5}
        ]}}
        """)
        let manager = CursorIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/new/agenticglow-event")
        )

        XCTAssertFalse(try manager.status().installed)
        try manager.repair()

        let text = try String(contentsOf: hooks, encoding: .utf8)
        XCTAssertTrue(try manager.status().installed)
        XCTAssertFalse(text.contains("/old/agenticglow-event"))
        XCTAssertTrue(text.contains("/new/agenticglow-event"))
        XCTAssertFalse(text.contains("failClosed"))
    }

    func testInstallRejectsMalformedHookShapeWithoutModification() throws {
        let original = #"{"hooks":{"sessionStart":{"command":"broken"}}}"#
        let hooks = temporaryConfig(contents: original)
        let manager = CursorIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        XCTAssertThrowsError(try manager.install())
        XCTAssertEqual(try String(contentsOf: hooks, encoding: .utf8), original)
    }

    func testRemoveUnmanagedConfigIsByteForByteNoOp() throws {
        let original = Data(#"{ "version" : 1, "hooks" : {} }"#.utf8)
        let hooks = temporaryConfig(data: original)
        let manager = CursorIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        try manager.remove()

        XCTAssertEqual(try Data(contentsOf: hooks), original)
        XCTAssertEqual(try backupURLs(beside: hooks), [])
    }

    func testStatusReportsIncompleteUntilEveryCursorEventIsPresent() throws {
        let hooks = temporaryConfig(contents: "{}")
        let manager = CursorIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        let status = try manager.status()
        XCTAssertFalse(status.installed)
        XCTAssertEqual(status.issue, "Cursor hooks need installation or repair.")
    }
}
