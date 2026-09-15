import XCTest
@testable import AgenticGlowCore

final class CursorHookPayloadTests: XCTestCase {
    func testMapsConversationAndWorkspaceRootsWithoutCopyingSecrets() {
        let payload: [String: Any] = [
            "conversation_id": "conv-123",
            "generation_id": "gen-456",
            "workspace_roots": ["/workspace/agenticglow"],
            "model": "composer-2.5",
            "prompt": "SECRET_PROMPT",
            "user_email": "secret@example.com",
            "transcript_path": "/tmp/secret-transcript.jsonl",
            "hook_event_name": "beforeSubmitPrompt"
        ]

        let normalized = CursorHookPayload.normalized(payload)

        XCTAssertEqual(normalized["session_id"] as? String, "conv-123")
        XCTAssertEqual(normalized["turn_id"] as? String, "gen-456")
        XCTAssertEqual(normalized["cwd"] as? String, "/workspace/agenticglow")
        XCTAssertNil(normalized["prompt"])
        XCTAssertNil(normalized["user_email"])
        XCTAssertNil(normalized["transcript_path"])
    }

    func testPrefersExplicitCwdOverWorkspaceRoots() {
        let normalized = CursorHookPayload.normalized([
            "conversation_id": "conv-123",
            "cwd": "/tmp/Moodpaper",
            "workspace_roots": ["/tmp/Other"]
        ])

        XCTAssertEqual(normalized["cwd"] as? String, "/tmp/Moodpaper")
    }

    func testInfersShellToolNameFromCommand() {
        let normalized = CursorHookPayload.normalized([
            "conversation_id": "conv-123",
            "cwd": "/tmp/Example",
            "command": "git status"
        ])

        XCTAssertEqual(normalized["tool_name"] as? String, "Shell")
    }

    func testKeepsExistingSessionIdentity() {
        let normalized = CursorHookPayload.normalized([
            "session_id": "already-set",
            "cwd": "/tmp/Example",
            "conversation_id": "conv-123"
        ])

        XCTAssertEqual(normalized["session_id"] as? String, "already-set")
    }
}
