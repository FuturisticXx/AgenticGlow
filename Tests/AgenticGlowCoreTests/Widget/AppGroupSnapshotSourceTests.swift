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

    func testDefaultInitializerNeverCrashesAndReportsNoRealData() {
        // No App Group entitlement exists in this pass. A real sandboxed
        // widget extension gets nil from containerURL(...) without the
        // entitlement (-> .notConfigured); this unsandboxed test host may
        // instead get a computed-but-empty path (-> .noSnapshotYet).
        // Either is correct as long as it never crashes and never claims
        // real data exists.
        let source = AppGroupSnapshotSource()
        switch source.loadSnapshot() {
        case .notConfigured, .noSnapshotYet:
            break
        case .corrupted, .loaded:
            XCTFail("Expected no real data without the App Group entitlement")
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppGroupSnapshotSourceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
