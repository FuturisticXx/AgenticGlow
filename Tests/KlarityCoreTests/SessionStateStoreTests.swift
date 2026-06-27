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

    func testLoadAllRejectsDirectoryOwnedByAnotherUser() throws {
        let directory = temporaryDirectory()
        let writeStore = FileSessionStateStore(directory: directory)
        let event = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try writeStore.write(event)

        let foreignStore = FileSessionStateStore(
            directory: directory,
            currentUserID: { getuid() + 1 }
        )

        XCTAssertThrowsError(try foreignStore.loadAll()) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeDirectory)
        }
    }

    func testLoadAllRejectsCurrentUserOwnedSharedModeDirectory() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let event = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try store.write(event)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: directory.path
        )

        XCTAssertEqual(try permissionMode(at: directory), 0o755)

        XCTAssertThrowsError(try store.loadAll()) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeDirectory)
        }
    }

    func testLoadRejectsDirectoryOwnedByAnotherUser() throws {
        let directory = temporaryDirectory()
        let writeStore = FileSessionStateStore(directory: directory)
        let event = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try writeStore.write(event)

        let foreignStore = FileSessionStateStore(
            directory: directory,
            currentUserID: { getuid() + 1 }
        )

        XCTAssertThrowsError(try foreignStore.load(SessionKey(event))) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeDirectory)
        }
    }

    func testLoadRejectsCurrentUserOwnedSharedModeSessionFile() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let event = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try store.write(event)
        let sessionFile = directory.appendingPathComponent(SessionKey(event).filename)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: sessionFile.path
        )

        XCTAssertEqual(try permissionMode(at: sessionFile), 0o644)

        XCTAssertThrowsError(try store.load(SessionKey(event))) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeFile)
        }
    }

    func testRemoveRejectsDirectoryOwnedByAnotherUser() throws {
        let directory = temporaryDirectory()
        let writeStore = FileSessionStateStore(directory: directory)
        let event = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try writeStore.write(event)

        let foreignStore = FileSessionStateStore(
            directory: directory,
            currentUserID: { getuid() + 1 }
        )

        XCTAssertThrowsError(try foreignStore.remove(SessionKey(event))) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeDirectory)
        }
    }

    func testRemoveRejectsCurrentUserOwnedSharedModeSessionFileWithoutRemovingIt() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let event = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try store.write(event)
        let sessionFile = directory.appendingPathComponent(SessionKey(event).filename)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: sessionFile.path
        )

        XCTAssertEqual(try permissionMode(at: sessionFile), 0o644)

        XCTAssertThrowsError(try store.remove(SessionKey(event))) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeFile)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionFile.path))
    }

    func testWriteReappliesPrivatePermissionsWhenOverwritingExistingSessionFile() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let original = stateFixture(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )
        let updated = NormalizedEvent(
            schemaVersion: original.schemaVersion,
            provider: original.provider,
            surface: original.surface,
            sessionID: original.sessionID,
            turnID: original.turnID,
            phase: .usingTool,
            label: "Editing",
            toolCategory: .edit,
            projectName: original.projectName,
            workingDirectory: original.workingDirectory,
            sourceBundleID: original.sourceBundleID,
            sourceProcessID: original.sourceProcessID,
            sourceProcessStartedAt: original.sourceProcessStartedAt,
            turnStartedAt: original.turnStartedAt,
            updatedAt: Date(timeIntervalSince1970: 121)
        )

        try store.write(original)
        let sessionFile = directory.appendingPathComponent(SessionKey(original).filename)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: sessionFile.path)

        XCTAssertEqual(try permissionMode(at: sessionFile), 0o644)

        try store.write(updated)

        XCTAssertEqual(try permissionMode(at: sessionFile), 0o600)
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

    private func permissionMode(at url: URL) throws -> UInt16 {
        let permissions = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return UInt16(truncating: permissions) & 0o777
    }
}
