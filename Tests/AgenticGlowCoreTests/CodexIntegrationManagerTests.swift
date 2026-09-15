import XCTest
@testable import AgenticGlowCore

final class CodexIntegrationManagerTests: XCTestCase {
    func testInstallCreatesSixSupportedEventsAndTrustMessage() throws {
        let hooks = temporaryConfig(contents: "{}")
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        try manager.install()

        let status = try manager.status()
        XCTAssertTrue(status.installed)
        XCTAssertTrue(status.requiresTrustReview)
        XCTAssertEqual(status.installedEvents, HookEventKind.codexEvents)
        XCTAssertEqual(status.issue, CodexIntegrationManager.trustInstruction)
    }

    func testInstallPreservesExistingHooksAndIsIdempotent() throws {
        let hooks = temporaryConfig(contents: """
        {"managed":{"keep":true},"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"existing-policy"}]}]}}
        """)
        let manager = CodexIntegrationManager(
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
        XCTAssertEqual((object["managed"] as? [String: Bool])?["keep"], true)
        XCTAssertTrue(text.contains("existing-policy"))
        XCTAssertEqual(text.components(separatedBy: "--agenticglow-hook").count - 1, 6)
    }

    func testRemoveDeletesOnlyAgenticGlowHooks() throws {
        let hooks = temporaryConfig(contents: """
        {"hooks":{"PreToolUse":[
          {"matcher":"Bash","hooks":[{"type":"command","command":"existing-policy"}]},
          {"matcher":"*","hooks":[{"type":"command","command":"'/tmp/agenticglow-event' codex PreToolUse --agenticglow-hook"}]}
        ]}}
        """)
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        try manager.remove()

        let text = try String(contentsOf: hooks, encoding: .utf8)
        XCTAssertTrue(text.contains("existing-policy"))
        XCTAssertFalse(text.contains("--agenticglow-hook"))
    }

    func testStatusDoesNotAcceptMarkerForDifferentHelper() throws {
        let hooks = temporaryConfig(contents: """
        {"hooks":{"SessionStart":[
          {"hooks":[{"type":"command","command":"\\\"/old/agenticglow-event\\\" codex SessionStart --agenticglow-hook"}]}
        ]}}
        """)
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/new/agenticglow-event")
        )

        let status = try manager.status()

        XCTAssertFalse(status.installed)
        XCTAssertFalse(status.requiresTrustReview)
        XCTAssertEqual(status.installedEvents, [])
        XCTAssertEqual(status.issue, "Codex hooks need installation or repair.")
    }

    func testStatusRejectsSymlinkedConfig() throws {
        let directory = privateIntegrationDirectory()
        let target = directory.appendingPathComponent("target.json")
        let hooks = directory.appendingPathComponent("hooks.json")
        try Data("{}".utf8).write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        try FileManager.default.createSymbolicLink(at: hooks, withDestinationURL: target)
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        XCTAssertThrowsError(try manager.status()) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeFile)
        }
    }

    func testStatusRejectsMalformedHookShape() throws {
        let hooks = temporaryConfig(contents: #"{"hooks":[]}"#)
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        XCTAssertThrowsError(try manager.status())
    }

    func testStatusRejectsNoncanonicalMatcherAndTimeoutFields() throws {
        enum Mutation {
            case removeMatcher
            case wrongMatcher
            case removeTimeout
            case wrongTimeout
        }

        let scenarios: [(HookEventKind, Mutation)] = [
            (.preToolUse, .removeMatcher),
            (.preToolUse, .wrongMatcher),
            (.sessionStart, .removeTimeout),
            (.sessionStart, .wrongTimeout)
        ]

        for (event, mutation) in scenarios {
            let hooks = temporaryConfig(contents: "{}")
            let manager = CodexIntegrationManager(
                hooksURL: hooks,
                helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
            )
            try manager.install()

            var object = try integrationJSONObject(hooks)
            var configuredHooks = try XCTUnwrap(object["hooks"] as? [String: Any])
            var groups = try XCTUnwrap(configuredHooks[event.rawValue] as? [[String: Any]])
            switch mutation {
            case .removeMatcher:
                groups[0].removeValue(forKey: "matcher")
            case .wrongMatcher:
                groups[0]["matcher"] = "Bash"
            case .removeTimeout:
                var handlers = try XCTUnwrap(groups[0]["hooks"] as? [[String: Any]])
                handlers[0].removeValue(forKey: "timeout")
                groups[0]["hooks"] = handlers
            case .wrongTimeout:
                var handlers = try XCTUnwrap(groups[0]["hooks"] as? [[String: Any]])
                handlers[0]["timeout"] = 10
                groups[0]["hooks"] = handlers
            }
            configuredHooks[event.rawValue] = groups
            object["hooks"] = configuredHooks
            try writeIntegrationJSONObject(object, to: hooks)

            let status = try manager.status()
            XCTAssertFalse(status.installed, "Unexpected canonical status for \(event) \(mutation)")
            XCTAssertFalse(status.installedEvents.contains(event))
        }
    }

    func testRemoveFindsOwnedHookInWrongGroupButPreservesMarkerLookalikes() throws {
        let hooks = temporaryConfig(contents: """
        {"hooks":{
          "SessionEnd":[{"hooks":[
            {"type":"command","command":"'/old/agenticglow-event' codex Stop --agenticglow-hook"}
          ]}],
          "Stop":[{"hooks":[
            {"type":"command","command":"existing-policy"},
            {"type":"command","command":"'/usr/local/bin/not-agenticglow' codex Stop --agenticglow-hook"},
            {"type":"command","command":"\\\"/tmp/agenticglow-event\\\" codex Stop --agenticglow-hook"},
            {"type":"command","command":"'/tmp/agenticglow-event' claude Stop --agenticglow-hook"}
          ]}]
        }}
        """)
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/new/agenticglow-event")
        )

        try manager.remove()

        let text = try String(contentsOf: hooks, encoding: .utf8)
        XCTAssertFalse(text.contains("/old/agenticglow-event"))
        XCTAssertTrue(text.contains("existing-policy"))
        XCTAssertTrue(text.contains("/usr/local/bin/not-agenticglow"))
        XCTAssertFalse(text.contains("\\\"/tmp/agenticglow-event\\\" codex"))
        XCTAssertTrue(text.contains("claude Stop"))
    }

    func testRemoveRecognizesDoubleQuotedAndObsoleteEventOwnedCommands() throws {
        let hooks = temporaryConfig(contents: """
        {"hooks":{"LegacyHook":[{"hooks":[
          {"type":"command","command":"\\\"/old/agenticglow-event\\\" codex Stop --agenticglow-hook"},
          {"type":"command","command":"'/old/agenticglow-event' codex BeforeModel --agenticglow-hook"},
          {"type":"command","command":"'/usr/local/bin/not-agenticglow' codex BeforeModel --agenticglow-hook"}
        ]}]}}
        """)
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/new/agenticglow-event")
        )

        try manager.remove()

        let text = try String(contentsOf: hooks, encoding: .utf8)
        XCTAssertFalse(text.contains("/old/agenticglow-event"))
        XCTAssertTrue(text.contains("/usr/local/bin/not-agenticglow"))
        XCTAssertEqual(text.components(separatedBy: "--agenticglow-hook").count - 1, 1)
    }

    func testRemoveMissingConfigDoesNotCreateIt() throws {
        let directory = privateIntegrationDirectory()
        let hooks = directory
            .appendingPathComponent("missing", isDirectory: true)
            .appendingPathComponent("hooks.json")
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/agenticglow-event")
        )

        try manager.remove()

        XCTAssertFalse(FileManager.default.fileExists(atPath: hooks.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: hooks.deletingLastPathComponent().path))
    }

    func testHookCommandPOSIXEscapesHostileHelperPath() {
        let helper = URL(fileURLWithPath: "/tmp/AgenticGlow's helper $HOME")

        XCTAssertEqual(
            HookDefinitionFactory.command(
                helperURL: helper,
                provider: .codex,
                event: .stop
            ),
            "'/tmp/AgenticGlow'\\''s helper $HOME' codex Stop --agenticglow-hook"
        )
    }
}

private extension HookEventKind {
    static let codexEvents: [HookEventKind] = [
        .sessionStart, .userPromptSubmit, .preToolUse,
        .postToolUse, .permissionRequest, .stop
    ]
}

func temporaryConfig(contents: String) -> URL {
    temporaryConfig(data: Data(contents.utf8))
}

func temporaryConfig(data: Data) -> URL {
    let directory = privateIntegrationDirectory()
    let url = directory.appendingPathComponent("config.json")
    try! data.write(to: url)
    try! FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    return url
}

func privateIntegrationDirectory() -> URL {
    let directory = temporaryDirectory()
    try! FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: directory.path
    )
    return directory
}

func backupURLs(beside config: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(
        at: config.deletingLastPathComponent(),
        includingPropertiesForKeys: nil
    ).filter {
        $0.lastPathComponent.hasPrefix("\(config.lastPathComponent).")
            && $0.lastPathComponent.hasSuffix(".bak-agenticglow")
    }
}

func integrationJSONObject(_ url: URL) throws -> [String: Any] {
    try XCTUnwrap(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    )
}

func writeIntegrationJSONObject(_ object: [String: Any], to url: URL) throws {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        .write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
}
