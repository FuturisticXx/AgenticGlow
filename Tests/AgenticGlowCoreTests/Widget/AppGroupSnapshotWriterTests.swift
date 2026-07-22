import Foundation
import XCTest
@testable import AgenticGlowCore

final class AppGroupSnapshotWriterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testWritesAndReadsBackViaTheMatchingSource() throws {
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

        let writer = AppGroupSnapshotWriter(containerDirectory: { directory })
        try writer.write(snapshot)

        let source = AppGroupSnapshotSource(containerDirectory: { directory })
        XCTAssertEqual(source.loadSnapshot(), .loaded(snapshot))
    }

    func testMissingContainerThrows() {
        let writer = AppGroupSnapshotWriter(containerDirectory: { nil })
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [],
            allowances: [],
            providers: [],
            attentionCount: 0,
            activeCount: 0
        )
        XCTAssertThrowsError(try writer.write(snapshot)) { error in
            XCTAssertEqual(error as? WidgetSnapshotWriteError, .containerUnavailable)
        }
    }

    func testOverwritesAPreviousSnapshot() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = AppGroupSnapshotWriter(containerDirectory: { directory })
        let source = AppGroupSnapshotSource(containerDirectory: { directory })

        try writer.write(WidgetSnapshot(
            generatedAt: now, sessions: [], allowances: [], providers: [],
            attentionCount: 1, activeCount: 1
        ))
        try writer.write(WidgetSnapshot(
            generatedAt: now, sessions: [], allowances: [], providers: [],
            attentionCount: 0, activeCount: 0
        ))

        guard case let .loaded(final) = source.loadSnapshot() else {
            return XCTFail("Expected a loaded snapshot")
        }
        XCTAssertEqual(final.attentionCount, 0)
        XCTAssertEqual(final.activeCount, 0)
    }

    func testDefaultInitializerFailsSafelyWithoutTheEntitlement() {
        // No App Group entitlement exists yet in this pass. On this system
        // containerURL(...) still returns a path without the entitlement
        // (see AppGroupSnapshotSourceTests), so the failure surfaces as a
        // lower-level file-system error rather than .containerUnavailable;
        // either is an acceptable, safe failure, never a crash.
        let writer = AppGroupSnapshotWriter()
        let snapshot = WidgetSnapshot(
            generatedAt: now, sessions: [], allowances: [], providers: [],
            attentionCount: 0, activeCount: 0
        )
        XCTAssertThrowsError(try writer.write(snapshot))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppGroupSnapshotWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
