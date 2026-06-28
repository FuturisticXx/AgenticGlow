import XCTest
@testable import KlarityCore

final class ClaudeIntegrationManagerTests: XCTestCase {
    func testInstallPreservesExistingHooksAndIsIdempotent() throws {
        let settings = temporaryConfig(contents: """
        {"theme":"dark","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"existing-policy"}]}]}}
        """)
        let manager = ClaudeIntegrationManager(
            settingsURL: settings,
            helperURL: URL(fileURLWithPath: "/tmp/klarity-event")
        )

        try manager.install()
        try manager.install()

        let object = try integrationJSONObject(settings)
        let text = String(
            decoding: try JSONSerialization.data(withJSONObject: object),
            as: UTF8.self
        )
        XCTAssertEqual(object["theme"] as? String, "dark")
        XCTAssertTrue(text.contains("existing-policy"))
        XCTAssertEqual(text.components(separatedBy: "--klarity-hook").count - 1, 8)
        XCTAssertEqual(try manager.status().installedEvents, HookEventKind.claudeEvents)
    }

    func testRemoveDeletesOnlyKlarityHooks() throws {
        let settings = temporaryConfig(contents: configuredClaudeSettings())
        let manager = ClaudeIntegrationManager(
            settingsURL: settings,
            helperURL: URL(fileURLWithPath: "/tmp/klarity-event")
        )

        try manager.remove()

        let text = try String(contentsOf: settings, encoding: .utf8)
        XCTAssertTrue(text.contains("existing-policy"))
        XCTAssertFalse(text.contains("--klarity-hook"))
    }

    func testRemovePreservesUnrelatedHandlerInSameMatcherGroup() throws {
        let settings = temporaryConfig(contents: """
        {"hooks":{"PreToolUse":[{"matcher":"*","hooks":[
          {"type":"command","command":"existing-policy"},
          {"type":"command","command":"\\\"/tmp/klarity-event\\\" claude PreToolUse --klarity-hook"}
        ]}]}}
        """)
        let manager = ClaudeIntegrationManager(
            settingsURL: settings,
            helperURL: URL(fileURLWithPath: "/tmp/klarity-event")
        )

        try manager.remove()

        let text = try String(contentsOf: settings, encoding: .utf8)
        XCTAssertTrue(text.contains("existing-policy"))
        XCTAssertFalse(text.contains("--klarity-hook"))
    }

    func testRepairReplacesStaleKlarityHookAndCompletesStatus() throws {
        let settings = temporaryConfig(contents: configuredClaudeSettings())
        let manager = ClaudeIntegrationManager(
            settingsURL: settings,
            helperURL: URL(fileURLWithPath: "/new/klarity-event")
        )

        XCTAssertFalse(try manager.status().installed)
        try manager.repair()

        let status = try manager.status()
        let text = try String(contentsOf: settings, encoding: .utf8)
        XCTAssertTrue(status.installed)
        XCTAssertFalse(status.requiresTrustReview)
        XCTAssertNil(status.issue)
        XCTAssertFalse(text.contains("/tmp/klarity-event"))
        XCTAssertEqual(text.components(separatedBy: "--klarity-hook").count - 1, 8)
    }

    func testInstallRejectsMalformedHookShapeWithoutModification() throws {
        let original = #"{"hooks":{"PreToolUse":{"command":"existing-policy"}}}"#
        let settings = temporaryConfig(contents: original)
        let manager = ClaudeIntegrationManager(
            settingsURL: settings,
            helperURL: URL(fileURLWithPath: "/tmp/klarity-event")
        )

        XCTAssertThrowsError(try manager.install())
        XCTAssertEqual(try String(contentsOf: settings, encoding: .utf8), original)
    }

    func testRemoveUnmanagedConfigIsByteForByteNoOp() throws {
        let original = Data(#"{ "theme" : "dark", "hooks" : {} }"#.utf8)
        let settings = temporaryConfig(data: original)
        let manager = ClaudeIntegrationManager(
            settingsURL: settings,
            helperURL: URL(fileURLWithPath: "/tmp/klarity-event")
        )

        try manager.remove()

        XCTAssertEqual(try Data(contentsOf: settings), original)
        XCTAssertEqual(try backupURLs(beside: settings), [])
    }
}

private extension HookEventKind {
    static let claudeEvents: [HookEventKind] = [
        .sessionStart, .sessionEnd, .userPromptSubmit, .preToolUse,
        .postToolUse, .notification, .permissionRequest, .stop
    ]
}

private func configuredClaudeSettings() -> String {
    """
    {
      "hooks": {
        "PreToolUse": [
          {"matcher":"Bash","hooks":[{"type":"command","command":"existing-policy"}]},
          {"matcher":"*","hooks":[{"type":"command","command":"\\\"/tmp/klarity-event\\\" claude PreToolUse --klarity-hook"}]}
        ]
      }
    }
    """
}
