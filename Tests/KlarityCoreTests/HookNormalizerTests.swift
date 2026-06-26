import XCTest
@testable import KlarityCore

final class HookNormalizerTests: XCTestCase {
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

        let encoded = try JSONEncoder.klarity.encode(event)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(encodedString.contains("SECRET_PROMPT"))
        XCTAssertFalse(encodedString.contains("tool_input"))
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

        let encoded = try JSONEncoder.klarity.encode(event)
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

        let encoded = try JSONEncoder.klarity.encode(event)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(encodedString.contains("SECRET_PATCH"))
        XCTAssertFalse(encodedString.contains("tool_input"))
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

        let encoded = try JSONEncoder.klarity.encode(event)
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

        let encoded = try JSONEncoder.klarity.encode(event)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("SECRET_MESSAGE"))
    }

    func testNonPermissionNotificationIsIgnored() throws {
        let payload: [String: Any] = [
            "session_id": "claude-session",
            "cwd": "/tmp/Example",
            "notification_type": "idle_prompt",
            "message": "Waiting for input",
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
}
