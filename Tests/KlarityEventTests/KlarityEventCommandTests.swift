import XCTest
@testable import KlarityCore

final class KlarityEventCommandTests: XCTestCase {
    func testCommandWritesNormalizedStateAndReturnsSuccess() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let command = KlarityEventCommand(
            store: store,
            processIdentity: { _, _ in .fixture }
        )
        let input = Data("""
        {"session_id":"codex-session","turn_id":"turn","cwd":"/tmp/Klarity","prompt":"SECRET"}
        """.utf8)

        let code = command.run(
            arguments: ["klarity-event", "codex", "UserPromptSubmit", "--klarity-hook"],
            input: input,
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(code, 0)
        let event = try XCTUnwrap(try store.loadAll().first)
        XCTAssertEqual(event.phase, .thinking)
        XCTAssertFalse(String(decoding: try JSONEncoder.klarity.encode(event), as: UTF8.self).contains("SECRET"))
    }

    func testCommandLoadsPreviousStateUsingNormalizedSessionKey() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let command = KlarityEventCommand(
            store: store,
            processIdentity: { _, _ in .fixture }
        )

        let firstCode = command.run(
            arguments: ["klarity-event", "codex", "UserPromptSubmit", "--klarity-hook"],
            input: Data("""
            {"session_id":"codex-session","turn_id":"turn-1","cwd":"/tmp/Klarity","prompt":"SECRET"}
            """.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )
        let secondCode = command.run(
            arguments: ["klarity-event", "codex", "PreToolUse", "--klarity-hook"],
            input: Data("""
            {"session_id":"codex-session","turn_id":"turn-2","cwd":"/tmp/Klarity","tool_name":"apply_patch"}
            """.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 501)
        )

        XCTAssertEqual(firstCode, 0)
        XCTAssertEqual(secondCode, 0)

        let event = try XCTUnwrap(try store.loadAll().first)
        XCTAssertEqual(event.phase, .usingTool)
        XCTAssertEqual(event.toolCategory, .edit)
        XCTAssertEqual(event.turnStartedAt, Date(timeIntervalSince1970: 500))
    }
}
