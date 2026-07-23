import Foundation
import XCTest
@testable import AgenticGlowCore

final class WidgetSnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testCodableRoundTrip() throws {
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [
                WidgetSessionSummary(
                    provider: .claude,
                    sessionID: "abc123",
                    projectName: "AgenticGlow",
                    phase: .thinking,
                    toolCategory: nil,
                    elapsedSeconds: 42,
                    updatedAt: now,
                    needsAttention: false
                )
            ],
            allowances: [
                WidgetAllowanceSummary(
                    provider: .claude,
                    currentWindowLabel: "5h",
                    currentPercentLeft: 72,
                    currentResetAt: now.addingTimeInterval(3600),
                    weeklyPercentLeft: 40,
                    weeklyResetAt: now.addingTimeInterval(86_400),
                    fetchedAt: now
                )
            ],
            providers: [
                WidgetProviderSummary(provider: .claude, installed: true),
                WidgetProviderSummary(provider: .codex, installed: false)
            ],
            attentionCount: 0,
            activeCount: 1
        )

        let data = try JSONEncoder.agenticglow.encode(snapshot)
        let decoded = try JSONDecoder.agenticglow.decode(WidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testDefaultSchemaVersionIsCurrent() {
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [],
            allowances: [],
            providers: [],
            attentionCount: 0,
            activeCount: 0
        )
        XCTAssertEqual(snapshot.schemaVersion, WidgetSnapshot.currentSchemaVersion)
    }

    func testEmptySnapshotHasNoSessionsOrAllowances() {
        XCTAssertTrue(WidgetSnapshot.empty.sessions.isEmpty)
        XCTAssertTrue(WidgetSnapshot.empty.allowances.isEmpty)
        XCTAssertEqual(WidgetSnapshot.empty.attentionCount, 0)
        XCTAssertEqual(WidgetSnapshot.empty.activeCount, 0)
    }

    func testDecodingAFutureSchemaVersionDoesNotThrow() throws {
        // A newer app version may bump schemaVersion; older widget code
        // (this test simulates it by hand-building the JSON) must still
        // decode the fields it knows about instead of failing outright.
        let json = """
        {"schemaVersion":99,"generatedAt":\(now.timeIntervalSince1970),
        "sessions":[],"allowances":[],"providers":[],"attentionCount":0,"activeCount":0}
        """
        let decoded = try JSONDecoder.agenticglow.decode(WidgetSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.schemaVersion, 99)
    }

    func testDecodingCorruptedDataFails() {
        let data = Data("not json".utf8)
        XCTAssertThrowsError(try JSONDecoder.agenticglow.decode(WidgetSnapshot.self, from: data))
    }
}
