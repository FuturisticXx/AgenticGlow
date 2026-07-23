import Foundation
import XCTest
@testable import AgenticGlowCore

final class CodexSessionDiscoveryTests: XCTestCase {
    func testRecentThreadSurvivesDeletedWorkingDirectoryWithoutReadingContent() async throws {
        let now = Date(timeIntervalSince1970: 1_784_693_300)
        let response = Data(
            """
            {"id":8,"result":{"data":[{"id":"thread-1","name":"SECRET title","preview":"SECRET prompt","cwd":"/Volumes/Liquid/2DaMax Development/DeletedProject","updatedAt":1784693299,"status":{"type":"notLoaded"},"source":"vscode"}],"nextCursor":null}}
            """.utf8
        )
        let adapter = CodexSessionDiscoveryAdapter(
            requester: StubCodexThreadRequester(data: response),
            workingDirectoryExists: { _ in false },
            now: { now }
        )

        let events = try await adapter.discover()

        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(event.provider, .codex)
        XCTAssertEqual(event.surface, .desktop)
        XCTAssertEqual(event.sessionID, HookNormalizer.sessionIdentifier("thread-1"))
        XCTAssertEqual(event.phase, .thinking)
        XCTAssertEqual(event.projectName, "Codex")
        XCTAssertEqual(event.workingDirectory, "/Volumes/Liquid/2DaMax Development/DeletedProject")
        XCTAssertFalse(String(describing: event).contains("SECRET"))
    }

    func testExistingWorkingDirectoryUsesItsProjectName() async throws {
        let response = Data(
            """
            {"id":8,"result":{"data":[{"id":"thread-2","cwd":"/Volumes/Liquid/2DaMax Development/AgenticGlow","updatedAt":1784693299,"status":{"type":"idle"},"source":"cli"}],"nextCursor":null}}
            """.utf8
        )
        let adapter = CodexSessionDiscoveryAdapter(
            requester: StubCodexThreadRequester(data: response),
            workingDirectoryExists: { $0 == "/Volumes/Liquid/2DaMax Development/AgenticGlow" },
            now: { Date(timeIntervalSince1970: 1_784_693_400) }
        )

        let events = try await adapter.discover()
        let event = try XCTUnwrap(events.first)

        XCTAssertEqual(event.surface, .cli)
        XCTAssertEqual(event.projectName, "AgenticGlow")
        XCTAssertEqual(event.phase, .idle)
    }

    func testHookEventWinsWithoutDuplicateWhenDiscoveryIsNearlyConcurrent() {
        let hook = event(
            sessionID: HookNormalizer.sessionIdentifier("thread-1"),
            phase: .usingTool,
            updatedAt: 100
        )
        let discovered = event(
            sessionID: HookNormalizer.sessionIdentifier("thread-1"),
            phase: .thinking,
            updatedAt: 101
        )

        let merged = SessionEventMerger.merge(
            stored: [hook],
            discoveredCodex: [discovered]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.phase, .usingTool)
    }

    func testDiscoveryReplacesStaleHookButPreservesClaude() {
        let staleHook = event(
            sessionID: HookNormalizer.sessionIdentifier("thread-1"),
            phase: .completed,
            updatedAt: 100
        )
        let discovered = event(
            sessionID: HookNormalizer.sessionIdentifier("thread-1"),
            phase: .thinking,
            updatedAt: 200
        )
        let claude = NormalizedEvent(
            schemaVersion: ProductMetadata.schemaVersion,
            provider: .claude,
            surface: .desktop,
            sessionID: "claude-session",
            turnID: nil,
            phase: .permission,
            label: "Awaiting permission",
            toolCategory: nil,
            projectName: "AgenticGlow",
            workingDirectory: "/Volumes/Liquid/2DaMax Development/AgenticGlow",
            sourceBundleID: "com.anthropic.claudefordesktop",
            sourceProcessID: nil,
            sourceProcessStartedAt: nil,
            turnStartedAt: Date(timeIntervalSince1970: 90),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let merged = SessionEventMerger.merge(
            stored: [staleHook, claude],
            discoveredCodex: [discovered]
        )

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first { $0.provider == .codex }?.phase, .thinking)
        XCTAssertEqual(merged.first { $0.provider == .claude }?.phase, .permission)
    }

    func testThreadListRequestUsesReadOnlyStateDatabaseAndNoContentFields() {
        let text = String(decoding: CodexThreadListProtocol.threadListRequest, as: UTF8.self)

        XCTAssertTrue(text.contains("thread/list"))
        XCTAssertTrue(text.contains("useStateDbOnly"))
        XCTAssertTrue(text.contains("updated_at"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("preview"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("transcript"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("prompt"))
    }

    func testThreadListClientCompletesInitializationAndReturnsThreadResponse() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("fake-codex")
        try Data(
            """
            #!/bin/sh
            IFS= read -r initialize
            printf '%s\\n' '{"id":1,"result":{}}'
            IFS= read -r initialized
            IFS= read -r request
            case "$request" in
              *'"method":"thread/list"'*'"useStateDbOnly":true'*)
                printf '%s\\n' '{"id":8,"result":{"data":[],"nextCursor":null}}'
                ;;
              *) exit 2 ;;
            esac
            """.utf8
        ).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        let response = try await CodexThreadListClient(executableURL: executable).readThreads()
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: response) as? [String: Any]
        )

        XCTAssertEqual((object["id"] as? NSNumber)?.intValue, 8)
    }

    private func event(
        sessionID: String,
        phase: SessionPhase,
        updatedAt: TimeInterval
    ) -> NormalizedEvent {
        NormalizedEvent(
            schemaVersion: ProductMetadata.schemaVersion,
            provider: .codex,
            surface: .desktop,
            sessionID: sessionID,
            turnID: nil,
            phase: phase,
            label: phase == .usingTool ? "Using tool" : phase == .completed ? "Completed" : "Thinking",
            toolCategory: nil,
            projectName: "AgenticGlow",
            workingDirectory: "/Volumes/Liquid/2DaMax Development/AgenticGlow",
            sourceBundleID: "com.openai.codex",
            sourceProcessID: nil,
            sourceProcessStartedAt: nil,
            turnStartedAt: Date(timeIntervalSince1970: updatedAt - 5),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }
}

private actor StubCodexThreadRequester: CodexThreadRequesting {
    private let data: Data

    init(data: Data) {
        self.data = data
    }

    func readThreads() async throws -> Data {
        data
    }
}
