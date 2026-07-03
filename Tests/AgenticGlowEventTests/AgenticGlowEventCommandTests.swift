import XCTest
@testable import AgenticGlowCore

final class AgenticGlowEventCommandTests: XCTestCase {
    func testCommandRecordsSuccessfulWriteWithoutRawPayload() throws {
        let directory = temporaryDirectory()
        let logger = RecordingDiagnosticLogger()
        let command = AgenticGlowEventCommand(
            store: FileSessionStateStore(directory: directory),
            processIdentity: { _, _ in .fixture },
            logger: logger
        )

        let code = command.run(
            arguments: ["agenticglow-event", "codex", "UserPromptSubmit", "--agenticglow-hook"],
            input: Data(#"{"session_id":"codex-session","cwd":"/tmp/AgenticGlow","prompt":"SECRET"}"#.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(code, 0)
        XCTAssertEqual(logger.records.count, 1)
        XCTAssertEqual(logger.records.first?.provider, .codex)
        XCTAssertEqual(logger.records.first?.event, .userPromptSubmit)
        XCTAssertEqual(logger.records.first?.result, "written")
        XCTAssertNil(logger.records.first?.rawPayload)
    }

    func testCommandWritesNormalizedStateAndReturnsSuccess() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let command = AgenticGlowEventCommand(
            store: store,
            processIdentity: { _, _ in .fixture }
        )
        let input = Data("""
        {"session_id":"codex-session","turn_id":"turn","cwd":"/tmp/AgenticGlow","prompt":"SECRET"}
        """.utf8)

        let code = command.run(
            arguments: ["agenticglow-event", "codex", "UserPromptSubmit", "--agenticglow-hook"],
            input: input,
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(code, 0)
        let event = try XCTUnwrap(try store.loadAll().first)
        XCTAssertEqual(event.phase, .thinking)
        XCTAssertFalse(String(decoding: try JSONEncoder.agenticglow.encode(event), as: UTF8.self).contains("SECRET"))
    }

    func testCommandLoadsPreviousStateUsingNormalizedSessionKey() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let command = AgenticGlowEventCommand(
            store: store,
            processIdentity: { _, _ in .fixture }
        )

        let firstCode = command.run(
            arguments: ["agenticglow-event", "codex", "UserPromptSubmit", "--agenticglow-hook"],
            input: Data("""
            {"session_id":"codex-session","turn_id":"turn-1","cwd":"/tmp/AgenticGlow","prompt":"SECRET"}
            """.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )
        let secondCode = command.run(
            arguments: ["agenticglow-event", "codex", "PreToolUse", "--agenticglow-hook"],
            input: Data("""
            {"session_id":"codex-session","turn_id":"turn-2","cwd":"/tmp/AgenticGlow","tool_name":"apply_patch"}
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

    func testCommandReturnsUsageErrorForMalformedOrNonDictionaryPayload() {
        let directory = temporaryDirectory()
        let command = AgenticGlowEventCommand(
            store: FileSessionStateStore(directory: directory),
            processIdentity: { _, _ in .fixture }
        )

        let malformedCode = command.run(
            arguments: ["agenticglow-event", "codex", "UserPromptSubmit", "--agenticglow-hook"],
            input: Data("{".utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )
        let arrayPayloadCode = command.run(
            arguments: ["agenticglow-event", "codex", "UserPromptSubmit", "--agenticglow-hook"],
            input: Data(#"["not","a","dictionary"]"#.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(malformedCode, 64)
        XCTAssertEqual(arrayPayloadCode, 64)
    }

    func testSessionEndRemovesExistingSessionState() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let command = AgenticGlowEventCommand(
            store: store,
            processIdentity: { _, _ in .fixture }
        )

        let startCode = command.run(
            arguments: ["agenticglow-event", "codex", "UserPromptSubmit", "--agenticglow-hook"],
            input: Data("""
            {"session_id":"codex-session","turn_id":"turn-1","cwd":"/tmp/AgenticGlow","prompt":"SECRET"}
            """.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )
        let endCode = command.run(
            arguments: ["agenticglow-event", "codex", "SessionEnd", "--agenticglow-hook"],
            input: Data("""
            {"session_id":"codex-session","cwd":"/tmp/AgenticGlow"}
            """.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 501)
        )

        XCTAssertEqual(startCode, 0)
        XCTAssertEqual(endCode, 0)
        XCTAssertEqual(try store.loadAll(), [])
    }
}

private final class RecordingDiagnosticLogger: DiagnosticLogging {
    struct Record {
        let provider: AgentProvider
        let event: HookEventKind
        let sessionID: String
        let result: String
        let rawPayload: String?
    }

    private(set) var records: [Record] = []

    func record(
        provider: AgentProvider,
        event: HookEventKind,
        sessionID: String,
        result: String,
        rawPayload: String?
    ) {
        records.append(.init(
            provider: provider,
            event: event,
            sessionID: sessionID,
            result: result,
            rawPayload: rawPayload
        ))
    }
}
