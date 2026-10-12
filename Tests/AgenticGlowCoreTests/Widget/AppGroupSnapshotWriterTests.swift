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

    /// T0 the widget holds 40% used, T1 the app stores 45%, T2 the
    /// widget's next timeline request reads 45%: the source reads the file
    /// on every request and holds nothing from an earlier one.
    func testNextReadAfterAWriteSeesTheNewAllowance() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = AppGroupSnapshotWriter(containerDirectory: { directory })
        let source = AppGroupSnapshotSource(containerDirectory: { directory })

        try writer.write(allowanceSnapshot(weeklyUsed: 40, fetchedAt: now))
        guard case let .loaded(first) = source.loadSnapshot() else { return XCTFail("Expected a snapshot") }
        XCTAssertEqual(first.allowances.first?.weeklyPercentLeft, 60)

        try writer.write(allowanceSnapshot(weeklyUsed: 45, fetchedAt: now.addingTimeInterval(60)))
        guard case let .loaded(second) = source.loadSnapshot() else { return XCTFail("Expected a snapshot") }
        XCTAssertEqual(second.allowances.first?.weeklyPercentLeft, 55)
        XCTAssertEqual(second.allowances.first?.fetchedAt, now.addingTimeInterval(60))
    }

    private func allowanceSnapshot(weeklyUsed: Double, fetchedAt: Date) -> WidgetSnapshot {
        WidgetSnapshotBuilder.build(
            resolved: ResolvedSessions(
                sessions: [], dominantPhase: .idle, activeCount: 0, permissionCount: 0, activeProviders: []
            ),
            allowances: [.claude: ProviderAllowance(
                provider: .claude,
                currentWindowLabel: "5h",
                currentPercentUsed: 10,
                currentResetAt: fetchedAt.addingTimeInterval(3600),
                weeklyPercentUsed: weeklyUsed,
                weeklyResetAt: fetchedAt.addingTimeInterval(86_400),
                fetchedAt: fetchedAt
            )],
            installedProviders: [.claude: true],
            now: fetchedAt
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppGroupSnapshotWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
