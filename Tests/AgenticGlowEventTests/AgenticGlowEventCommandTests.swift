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

    func testCommandRedactsSessionIDWhenStoreFailureIsLogged() throws {
        let rawSessionID = "private-session-id-must-not-reach-diagnostics"
        let logger = RecordingDiagnosticLogger()
        let command = AgenticGlowEventCommand(
            store: FailingWriteSessionStore(),
            processIdentity: { _, _ in .fixture },
            logger: logger
        )

        let code = command.run(
            arguments: ["agenticglow-event", "codex", "UserPromptSubmit", "--agenticglow-hook"],
            input: Data("""
            {"session_id":"\(rawSessionID)","cwd":"/tmp/AgenticGlow"}
            """.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(code, 1)
        let record = try XCTUnwrap(logger.records.first)
        XCTAssertEqual(record.sessionID, HookNormalizer.sessionIdentifier(rawSessionID))
        XCTAssertFalse(record.sessionID.contains(rawSessionID))
        XCTAssertNil(record.rawPayload)
    }

    func testCommandRedactsSessionIDWhenNormalizationFails() throws {
        let rawSessionID = "private-session-id\nwith-a-control-character"
        let logger = RecordingDiagnosticLogger()
        let command = AgenticGlowEventCommand(
            store: FailingWriteSessionStore(),
            processIdentity: { _, _ in .fixture },
            logger: logger
        )

        let code = command.run(
            arguments: ["agenticglow-event", "codex", "UserPromptSubmit", "--agenticglow-hook"],
            input: Data(#"{"session_id":"private-session-id\nwith-a-control-character","cwd":"relative"}"#.utf8),
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(code, 1)
        let record = try XCTUnwrap(logger.records.first)
        XCTAssertEqual(record.sessionID, HookNormalizer.sessionIdentifier(rawSessionID))
        XCTAssertFalse(record.sessionID.contains(rawSessionID))
        XCTAssertNil(record.rawPayload)
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

    // Codex runs PermissionRequest hooks before routing a request to either
    // its automatic reviewer or the user, so the hook alone cannot say the
    // user is blocked. The turn's reviewer decides it.
    func testCodexPermissionRequestUnderAutoReviewDoesNotAwaitPermission() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let logger = RecordingDiagnosticLogger()
        let command = AgenticGlowEventCommand(store: store, processIdentity: { _, _ in .fixture }, logger: logger)
        let transcript = try codexTranscript(
            in: directory,
            turnContexts: [
                #"{"approval_policy":"on-request","approvals_reviewer":"user"}"#,
                #"{"approval_policy":"on-request","approvals_reviewer":"auto_review"}"#
            ]
        )

        let toolCode = runCodex(command, "PreToolUse", transcript: transcript, now: 500)
        let permissionCode = runCodex(command, "PermissionRequest", transcript: transcript, now: 501)

        XCTAssertEqual(toolCode, 0)
        XCTAssertEqual(permissionCode, 0)
        let event = try XCTUnwrap(try store.loadAll().first)
        XCTAssertEqual(event.phase, .usingTool)
        XCTAssertEqual(logger.records.last?.result, "skipped:reviewer=auto-review")
    }

    func testCodexPermissionRequestForUserReviewerAwaitsPermission() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let logger = RecordingDiagnosticLogger()
        let command = AgenticGlowEventCommand(store: store, processIdentity: { _, _ in .fixture }, logger: logger)
        let transcript = try codexTranscript(
            in: directory,
            turnContexts: [
                #"{"approval_policy":"on-request","approvals_reviewer":"auto_review"}"#,
                #"{"approval_policy":"on-request","approvals_reviewer":"user"}"#
            ]
        )

        let code = runCodex(command, "PermissionRequest", transcript: transcript, now: 501)

        XCTAssertEqual(code, 0)
        XCTAssertEqual(try XCTUnwrap(try store.loadAll().first).phase, .permission)
        XCTAssertEqual(logger.records.last?.result, "written:reviewer=user")
    }

    func testCodexPermissionRequestWithoutReadableTranscriptAwaitsPermission() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let logger = RecordingDiagnosticLogger()
        let command = AgenticGlowEventCommand(store: store, processIdentity: { _, _ in .fixture }, logger: logger)

        let code = runCodex(
            command,
            "PermissionRequest",
            transcript: directory.appendingPathComponent("missing.jsonl").path,
            now: 501
        )

        XCTAssertEqual(code, 0)
        XCTAssertEqual(try XCTUnwrap(try store.loadAll().first).phase, .permission)
        XCTAssertEqual(logger.records.last?.result, "written:reviewer=user-assumed:no-turn-context")
    }

    // Contract with Codex 0.153.2: the payload carries every field of Codex's
    // `PermissionRequestCommandInput`, and the transcripts copy the shape of
    // its rollout lines with personal values replaced. If a Codex update
    // changes either shape, these fail instead of false alarms returning.
    func testCodexContractAutoReviewTranscriptDoesNotAwaitPermission() throws {
        let (phase, log) = try runCodexContract(transcript: "transcript-auto-review")

        XCTAssertNil(phase)
        XCTAssertEqual(log, "skipped:reviewer=auto-review")
    }

    func testCodexContractUserReviewerTranscriptAwaitsPermission() throws {
        let (phase, log) = try runCodexContract(transcript: "transcript-user-reviewer")

        XCTAssertEqual(phase, .permission)
        XCTAssertEqual(log, "written:reviewer=user")
    }

    func testCursorPayloadMapsConversationIdentityAndOmitsSecrets() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let command = AgenticGlowEventCommand(
            store: store,
            processIdentity: { _, _ in .fixture }
        )
        let input = Data("""
        {"conversation_id":"conv-live-secret","generation_id":"gen-1","workspace_roots":["/tmp/Moodpaper"],"model":"composer-2.5","prompt":"SECRET_PROMPT","user_email":"secret@example.com","transcript_path":"/tmp/secret.jsonl"}
        """.utf8)

        let code = command.run(
            arguments: ["agenticglow-event", "cursor", "UserPromptSubmit", "--agenticglow-hook"],
            input: input,
            environment: [:],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(code, 0)
        let event = try XCTUnwrap(try store.loadAll().first)
        XCTAssertEqual(event.provider, .cursor)
        XCTAssertEqual(event.phase, .thinking)
        XCTAssertEqual(event.projectName, "Moodpaper")
        XCTAssertEqual(event.model, "composer-2.5")
        XCTAssertTrue(event.sessionID.hasPrefix("sid_"))
        let encoded = String(decoding: try JSONEncoder.agenticglow.encode(event), as: UTF8.self)
        XCTAssertFalse(encoded.contains("SECRET_PROMPT"))
        XCTAssertFalse(encoded.contains("secret@example.com"))
        XCTAssertFalse(encoded.contains("conv-live-secret"))
        XCTAssertFalse(encoded.contains("/tmp/secret.jsonl"))
    }

    /// A rollout shaped like Codex's: one compact JSON object per line, with
    /// large unrelated lines after the newest turn context, the way tool
    /// output follows it in a long turn.
    private func codexTranscript(in directory: URL, turnContexts: [String]) throws -> String {
        let filler = String(repeating: "x", count: 300_000)
        var lines = [#"{"type":"session_meta","payload":{}}"#]
        for context in turnContexts {
            lines.append(#"{"timestamp":"t","type":"turn_context","payload":"# + context + "}")
            lines.append(#"{"type":"response_item","payload":{"output":"\"type\":\"turn_context\" "# + filler + #""}}"#)
        }
        let url = directory.appendingPathComponent("rollout.jsonl")
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url)
        return url.path
    }

    private func runCodexContract(transcript: String) throws -> (SessionPhase?, String?) {
        let fixtures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/codex")
        let transcriptPath = fixtures.appendingPathComponent("\(transcript).jsonl").path
        let payload = try String(
            contentsOf: fixtures.appendingPathComponent("permission-request-payload.json"),
            encoding: .utf8
        ).replacingOccurrences(of: "TRANSCRIPT_PATH", with: transcriptPath)
        // A directory the store creates itself, so an empty one still reads
        // as private when nothing was written.
        let store = FileSessionStateStore(directory: temporaryDirectory().appendingPathComponent("Sessions"))
        let logger = RecordingDiagnosticLogger()
        let command = AgenticGlowEventCommand(store: store, processIdentity: { _, _ in .fixture }, logger: logger)

        let code = command.run(
            arguments: ["agenticglow-event", "codex", "PermissionRequest", "--agenticglow-hook"],
            input: Data(payload.utf8),
            environment: [:],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(code, 0)
        let event = try store.loadAll().first
        if let event {
            let encoded = String(decoding: try JSONEncoder.agenticglow.encode(event), as: UTF8.self)
            XCTAssertFalse(encoded.contains("SECRET_COMMAND_MUST_NOT_PERSIST"))
            XCTAssertFalse(encoded.contains(transcriptPath))
        }
        return (event?.phase, logger.records.last?.result)
    }

    private func runCodex(
        _ command: AgenticGlowEventCommand,
        _ event: String,
        transcript: String,
        now: TimeInterval
    ) -> Int32 {
        command.run(
            arguments: ["agenticglow-event", "codex", event, "--agenticglow-hook"],
            input: Data("""
            {"session_id":"codex-session","turn_id":"turn","cwd":"/tmp/AgenticGlow","tool_name":"Bash","transcript_path":"\(transcript)"}
            """.utf8),
            environment: [:],
            now: Date(timeIntervalSince1970: now)
        )
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

private struct FailingWriteSessionStore: SessionStateStoring {
    enum Failure: Error {
        case writeFailed
    }

    func write(_ event: NormalizedEvent) throws {
        throw Failure.writeFailed
    }

    func loadAll() throws -> [NormalizedEvent] { [] }
    func load(_ key: SessionKey) throws -> NormalizedEvent? { nil }
    func remove(_ key: SessionKey) throws {}
}
