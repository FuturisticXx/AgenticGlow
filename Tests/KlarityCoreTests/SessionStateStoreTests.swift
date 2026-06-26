import XCTest
@testable import KlarityCore

final class SessionStateStoreTests: XCTestCase {
    func testWriteLoadAndRemoveUseOneFilePerSession() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let event = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try store.write(event)

        XCTAssertEqual(try store.loadAll(), [event])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)

        try store.remove(SessionKey(event))

        XCTAssertEqual(try store.loadAll(), [])
    }

    func testWriteRejectsSymlinkedSessionDirectory() throws {
        let root = temporaryDirectory()
        let target = root.appendingPathComponent("target", isDirectory: true)
        let link = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let store = FileSessionStateStore(directory: link)

        XCTAssertThrowsError(try store.write(stateFixture(
            provider: .claude,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )))
    }

    func testLoadAllIgnoresMalformedFilesWithoutDroppingValidSessions() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let event = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try store.write(event)
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("malformed.json"))

        XCTAssertEqual(try store.loadAll(), [event])
    }

    private func stateFixture(
        provider: AgentProvider,
        phase: SessionPhase,
        turnStartedAt: Date?
    ) -> NormalizedEvent {
        NormalizedEvent(
            schemaVersion: ProductMetadata.schemaVersion,
            provider: provider,
            surface: .cli,
            sessionID: "sid_test_session",
            turnID: "tid_test_turn",
            phase: phase,
            label: phase == .thinking ? "Thinking" : phase.rawValue,
            toolCategory: nil,
            projectName: "Klarity",
            workingDirectory: "/tmp/Klarity",
            sourceBundleID: "com.apple.Terminal",
            sourceProcessID: 123,
            sourceProcessStartedAt: Date(timeIntervalSince1970: 50),
            turnStartedAt: turnStartedAt,
            updatedAt: Date(timeIntervalSince1970: 120)
        )
    }
}
