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

    func testUnreadableFileIsUnreadableNotWaiting() throws {
        // A widget binary that macOS refuses access to the TCC-protected
        // group container sees exactly this: the file is there, the read
        // fails. That must not be reported as "the app hasn't run yet".
        try XCTSkipIf(geteuid() == 0, "root can read a mode-000 file")
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(AppGroupSnapshotSource.snapshotFilename)
        try JSONEncoder.agenticglow.encode(WidgetSnapshot.empty).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }

        let source = AppGroupSnapshotSource(containerDirectory: { directory })
        XCTAssertEqual(source.loadSnapshot(), .unreadable)
    }

    func testMissingFileClassificationFollowsTheError() {
        XCTAssertTrue(AppGroupSnapshotSource.isMissingFile(CocoaError(.fileReadNoSuchFile)))
        XCTAssertTrue(AppGroupSnapshotSource.isMissingFile(POSIXError(.ENOENT)))
        XCTAssertTrue(AppGroupSnapshotSource.isMissingFile(NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.fileReadUnknown.rawValue,
            userInfo: [NSUnderlyingErrorKey: POSIXError(.ENOENT)]
        )))
        XCTAssertFalse(AppGroupSnapshotSource.isMissingFile(CocoaError(.fileReadNoPermission)))
        XCTAssertFalse(AppGroupSnapshotSource.isMissingFile(POSIXError(.EPERM)))
        XCTAssertFalse(AppGroupSnapshotSource.isMissingFile(POSIXError(.EACCES)))
    }

    func testStaleSnapshotStillLoads() throws {
        // Age is a presentation concern (WidgetDataFreshness), never a
        // reason to drop back to an empty state: an old number with its
        // timestamp beats no number.
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let old = now.addingTimeInterval(-(WidgetDataFreshness.staleThreshold + 1))
        let snapshot = WidgetSnapshot(
            generatedAt: old, sessions: [], allowances: [], providers: [],
            attentionCount: 0, activeCount: 0
        )
        let url = directory.appendingPathComponent(AppGroupSnapshotSource.snapshotFilename)
        try JSONEncoder.agenticglow.encode(snapshot).write(to: url)

        let source = AppGroupSnapshotSource(containerDirectory: { directory })
        XCTAssertEqual(source.loadSnapshot(), .loaded(snapshot))
        XCTAssertEqual(WidgetDataFreshness.evaluate(generatedAt: old, now: now), .stale)
    }

    func testProductionReaderResolvesTheSharedContainerAndNeverCrashes() {
        // The production initializer, not the testing seam. Whether this
        // process may read the container depends on the machine, so only
        // the resolution and the absence of a crash are asserted.
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupSnapshotSource.appGroupIdentifier
        )
        XCTAssertEqual(container?.lastPathComponent, AppGroupSnapshotSource.appGroupIdentifier)
        switch AppGroupSnapshotSource().loadSnapshot() {
        case .notConfigured, .noSnapshotYet, .unreadable, .corrupted, .loaded:
            break
        }
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
