import XCTest
@testable import AgenticGlowCore

final class HookNormalizerTests: XCTestCase {
    func testClaudePromptHashesRawSessionIdentifierWithoutPersistingIt() throws {
        let payload: [String: Any] = [
            "session_id": "sk-live-secret-session-token",
            "cwd": "/tmp/Example",
            "prompt": "SECRET_PROMPT_MUST_NOT_PERSIST",
        ]

        let first = try XCTUnwrap(HookNormalizer.normalize(
            provider: .claude,
            event: .userPromptSubmit,
            payload: payload,
            environment: [:],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 500)
        ))
        let second = try XCTUnwrap(HookNormalizer.normalize(
            provider: .claude,
            event: .userPromptSubmit,
            payload: payload,
            environment: [:],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 501)
        ))

        XCTAssertEqual(first.sessionID, second.sessionID)
        XCTAssertNotEqual(first.sessionID, "sk-live-secret-session-token")
        XCTAssertTrue(first.sessionID.hasPrefix("sid_"))
        XCTAssertLessThanOrEqual(first.sessionID.count, 128)
        XCTAssertTrue(first.sessionID.unicodeScalars.allSatisfy(Self.allowedIdentifierScalars.contains))

        let encoded = try JSONEncoder.agenticglow.encode(first)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("sk-live-secret-session-token"))
    }

    func testClaudePromptStartsThinkingTimerWithoutPersistingPrompt() throws {
        let payload = try fixture("claude/user-prompt-submit")
        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .claude,
            event: .userPromptSubmit,
            payload: payload,
            environment: [
                "TERM_PROGRAM": "Apple_Terminal",
                "__CFBundleIdentifier": "com.apple.Terminal",
            ],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 500)
        ))

        XCTAssertEqual(event.phase, .thinking)
        XCTAssertEqual(event.turnStartedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(event.surface, .cli)
        XCTAssertEqual(event.sourceBundleID, "com.apple.Terminal")

        let encoded = try JSONEncoder.agenticglow.encode(event)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(encodedString.contains("SECRET_PROMPT"))
        XCTAssertFalse(encodedString.contains("tool_input"))
    }

    func testCLIPersistsProcessIdentityBundleWhenEnvironmentBundleIsMissing() throws {
        let processIdentity = ProcessIdentity(
            processID: 123,
            startedAt: Date(timeIntervalSince1970: 100),
            bundleIdentifier: "com.apple.Terminal"
        )

        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .codex,
            event: .preToolUse,
            payload: try fixture("codex/pre-tool-use"),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            processIdentity: processIdentity,
            previous: nil,
            now: Date(timeIntervalSince1970: 500)
        ))

        XCTAssertEqual(event.surface, .cli)
        XCTAssertEqual(event.sourceBundleID, "com.apple.Terminal")
    }

    func testClaudePermissionRequestDoesNotPersistCommand() throws {
        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .claude,
            event: .permissionRequest,
            payload: try fixture("claude/permission-request"),
            environment: [:],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 500)
        ))

        XCTAssertEqual(event.phase, .permission)
        XCTAssertEqual(event.label, "Awaiting permission")
        XCTAssertEqual(event.surface, .desktop)
        XCTAssertEqual(event.sourceBundleID, ProcessIdentity.fixture.bundleIdentifier)

        let encoded = try JSONEncoder.agenticglow.encode(event)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(encodedString.contains("SECRET_COMMAND"))
        XCTAssertFalse(encodedString.contains("tool_input"))
    }

    func testCodexPreToolUseMapsApplyPatchToEditingAndPreservesTimer() throws {
        let previous = NormalizedEvent.testEvent(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 400)
        )
        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .codex,
            event: .preToolUse,
            payload: try fixture("codex/pre-tool-use"),
            environment: [:],
            processIdentity: .fixture,
            previous: previous,
            now: Date(timeIntervalSince1970: 501)
        ))

        XCTAssertEqual(event.phase, .usingTool)
        XCTAssertEqual(event.toolCategory, .edit)
        XCTAssertEqual(event.label, "Editing")
        XCTAssertEqual(event.turnStartedAt, Date(timeIntervalSince1970: 400))

        let encoded = try JSONEncoder.agenticglow.encode(event)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(encodedString.contains("SECRET_PATCH"))
        XCTAssertFalse(encodedString.contains("tool_input"))
    }

    func testCodexPreToolUseHashesRawTurnIdentifierWithoutPersistingIt() throws {
        let payload: [String: Any] = [
            "session_id": "codex-session",
            "turn_id": "raw-turn-secret-token",
            "cwd": "/tmp/AgenticGlow",
            "tool_name": "apply_patch",
        ]

        let first = try XCTUnwrap(HookNormalizer.normalize(
            provider: .codex,
            event: .preToolUse,
            payload: payload,
            environment: [:],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 501)
        ))
        let second = try XCTUnwrap(HookNormalizer.normalize(
            provider: .codex,
            event: .preToolUse,
            payload: payload,
            environment: [:],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 502)
        ))

        let firstTurnID = try XCTUnwrap(first.turnID)
        XCTAssertEqual(firstTurnID, second.turnID)
        XCTAssertNotEqual(firstTurnID, "raw-turn-secret-token")
        XCTAssertTrue(firstTurnID.hasPrefix("tid_"))
        XCTAssertLessThanOrEqual(firstTurnID.count, 128)
        XCTAssertTrue(firstTurnID.unicodeScalars.allSatisfy(Self.allowedIdentifierScalars.contains))

        let encoded = try JSONEncoder.agenticglow.encode(first)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("raw-turn-secret-token"))
    }

    func testPreToolUseWithoutPreviousKeepsNilTurnTimer() throws {
        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .codex,
            event: .preToolUse,
            payload: try fixture("codex/pre-tool-use"),
            environment: [:],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 501)
        ))

        XCTAssertNil(event.turnStartedAt)
    }

    func testPermissionRequestWithoutPreviousKeepsNilTurnTimer() throws {
        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .claude,
            event: .permissionRequest,
            payload: try fixture("claude/permission-request"),
            environment: [:],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 500)
        ))

        XCTAssertNil(event.turnStartedAt)
    }

    func testCodexStopDoesNotPersistResponseContent() throws {
        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .codex,
            event: .stop,
            payload: try fixture("codex/stop"),
            environment: [:],
            processIdentity: .fixture,
            previous: NormalizedEvent.testEvent(
                provider: .codex,
                phase: .thinking,
                turnStartedAt: Date(timeIntervalSince1970: 400)
            ),
            now: Date(timeIntervalSince1970: 502)
        ))

        XCTAssertEqual(event.phase, .completed)
        XCTAssertNil(event.turnStartedAt)
        XCTAssertEqual(event.surface, .desktop)

        let encoded = try JSONEncoder.agenticglow.encode(event)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("SECRET_RESPONSE"))
    }

    func testPermissionNotificationDoesNotPersistMessageContent() throws {
        let payload: [String: Any] = [
            "session_id": "claude-session",
            "cwd": "/tmp/Example",
            "notification_type": "permission_prompt",
            "message": "SECRET_MESSAGE_MUST_NOT_PERSIST approve?",
        ]

        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .claude,
            event: .notification,
            payload: payload,
            environment: [:],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 503)
        ))

        XCTAssertEqual(event.phase, .permission)
        XCTAssertNil(event.turnStartedAt)

        let encoded = try JSONEncoder.agenticglow.encode(event)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("SECRET_MESSAGE"))
    }

    func testNonPermissionNotificationIsIgnored() throws {
        let payload: [String: Any] = [
            "session_id": "claude-session",
            "cwd": "/tmp/Example",
            "notification_type": "idle_prompt",
            "message": "Please approve permission to continue",
        ]

        XCTAssertNil(try HookNormalizer.normalize(
            provider: .claude,
            event: .notification,
            payload: payload,
            environment: [:],
            processIdentity: nil,
            previous: nil,
            now: Date()
        ))
    }

    func testUnknownToolMapsToOtherWithGenericLabel() throws {
        let payload: [String: Any] = [
            "session_id": "codex-session",
            "turn_id": "turn-2",
            "cwd": "/tmp/AgenticGlow",
            "tool_name": "mystery_tool",
        ]

        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .codex,
            event: .preToolUse,
            payload: payload,
            environment: [:],
            processIdentity: .fixture,
            previous: NormalizedEvent.testEvent(
                provider: .codex,
                phase: .thinking,
                turnStartedAt: Date(timeIntervalSince1970: 400)
            ),
            now: Date(timeIntervalSince1970: 501)
        ))

        XCTAssertEqual(event.toolCategory, .other)
        XCTAssertEqual(event.label, "Using tool")
    }

    func testValidationRejectsUnsafeTurnIdentifier() {
        let event = NormalizedEvent(
            schemaVersion: 1,
            provider: .codex,
            surface: .cli,
            sessionID: "session-1",
            turnID: "../turn",
            phase: .thinking,
            label: "Thinking",
            toolCategory: nil,
            projectName: "AgenticGlow",
            workingDirectory: "/tmp/AgenticGlow",
            sourceBundleID: "com.apple.Terminal",
            sourceProcessID: 123,
            sourceProcessStartedAt: Date(timeIntervalSince1970: 100),
            turnStartedAt: Date(timeIntervalSince1970: 110),
            updatedAt: Date(timeIntervalSince1970: 120)
        )

        XCTAssertThrowsError(try event.validate())
    }

    private func fixture(_ name: String) throws -> [String: Any] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("Fixtures/\(name).json")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private static let allowedIdentifierScalars = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "._-")
    )
}
