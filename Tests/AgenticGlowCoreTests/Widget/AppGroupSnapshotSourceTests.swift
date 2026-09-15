import Foundation
import XCTest
@testable import AgenticGlowCore

final class AppGroupSnapshotSourceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testMissingContainerIsNotConfigured() {
        let source = AppGroupSnapshotSource(containerDirectory: { nil })
        XCTAssertEqual(source.loadSnapshot(), .notConfigured)
    }

    func testMissingFileIsNoSnapshotYet() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = AppGroupSnapshotSource(containerDirectory: { directory })
        XCTAssertEqual(source.loadSnapshot(), .noSnapshotYet)
    }

    func testCorruptedFileIsCorruptedNotACrash() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(AppGroupSnapshotSource.snapshotFilename)
        try Data("not valid json".utf8).write(to: url)

        let source = AppGroupSnapshotSource(containerDirectory: { directory })
        XCTAssertEqual(source.loadSnapshot(), .corrupted)
    }

    func testValidFileDecodesSuccessfully() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [],
            allowances: [],
            providers: [],
            attentionCount: 0,
            activeCount: 0
        )
        let url = directory.appendingPathComponent(AppGroupSnapshotSource.snapshotFilename)
        try JSONEncoder.agenticglow.encode(snapshot).write(to: url)

        let source = AppGroupSnapshotSource(containerDirectory: { directory })
        XCTAssertEqual(source.loadSnapshot(), .loaded(snapshot))
    }

    func testAppGroupIdentifierMatchesProductionValue() {
        // This test prevents accidental drift of the App Group identifier.
        // The production value must be Team-ID-prefixed for macOS non-sandboxed app
        // + sandboxed widget extension compatibility.
        XCTAssertEqual(
            AppGroupSnapshotSource.appGroupIdentifier,
            "Z52AX2BH7T.group.com.twodamax.agenticglow",
            "App Group identifier must match production Team ID value"
        )
    }

    func testAppGroupIdentifierIsNotBareGroupForm() {
        // Bare group.com.twodamax.agenticglow form was previously broken
        // for non-sandboxed app + sandboxed widget architecture.
        XCTAssertFalse(
            AppGroupSnapshotSource.appGroupIdentifier.hasPrefix("group."),
            "App Group must use Team ID prefix, not bare group. form"
        )
        XCTAssertTrue(
            AppGroupSnapshotSource.appGroupIdentifier.hasPrefix("Z52AX2BH7T."),
            "App Group must be prefixed with Team ID Z52AX2BH7T"
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppGroupSnapshotSourceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
