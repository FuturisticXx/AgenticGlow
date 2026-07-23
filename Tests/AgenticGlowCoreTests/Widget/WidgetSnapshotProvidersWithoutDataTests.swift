import Foundation
import XCTest
@testable import AgenticGlowCore

final class WidgetSnapshotProvidersWithoutDataTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testProviderWithSessionsButNoHookInstallIsNotFlaggedMissing() {
        let session = WidgetSessionSummary(
            provider: .codex, sessionID: "s1", projectName: "AgenticGlow",
            phase: .idle, toolCategory: nil, elapsedSeconds: nil, updatedAt: now, needsAttention: false
        )
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [session],
            allowances: [],
            providers: [WidgetProviderSummary(provider: .codex, installed: false)],
            attentionCount: 0,
            activeCount: 0
        )
        XCTAssertTrue(snapshot.providersWithoutData.isEmpty)
    }

    func testProviderWithAllowanceButNoHookInstallIsNotFlaggedMissing() {
        let allowance = WidgetAllowanceSummary(
            provider: .codex, currentWindowLabel: "Weekly", currentPercentLeft: 14,
            currentResetAt: now, weeklyPercentLeft: nil, weeklyResetAt: nil, fetchedAt: now
        )
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [],
            allowances: [allowance],
            providers: [WidgetProviderSummary(provider: .codex, installed: false)],
            attentionCount: 0,
            activeCount: 0
        )
        XCTAssertTrue(snapshot.providersWithoutData.isEmpty)
    }

    func testProviderWithNoSignalAtAllIsFlaggedMissing() {
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [],
            allowances: [],
            providers: [WidgetProviderSummary(provider: .codex, installed: false)],
            attentionCount: 0,
            activeCount: 0
        )
        XCTAssertEqual(snapshot.providersWithoutData, [.codex])
    }

    func testInstalledProviderIsNeverFlaggedRegardlessOfData() {
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [],
            allowances: [],
            providers: [WidgetProviderSummary(provider: .claude, installed: true)],
            attentionCount: 0,
            activeCount: 0
        )
        XCTAssertTrue(snapshot.providersWithoutData.isEmpty)
    }
}
