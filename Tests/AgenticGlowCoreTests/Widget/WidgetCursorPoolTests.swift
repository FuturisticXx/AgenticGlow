import Foundation
import XCTest
@testable import AgenticGlowCore

/// The widget consumes pools through the same `windows` projection every
/// size already renders, so app and widget can never disagree about what
/// a Cursor number means.
final class WidgetCursorPoolTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testPoolsBecomeOneDisplayWindowEachWithStableIdentity() {
        let summary = cursorSummary(cursorModels: 74, otherModels: 6)

        let windows = summary.windows

        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows.map(\.label), ["Cursor Models", "Other Models"])
        XCTAssertEqual(windows.map(\.id), ["cursor:cursorModels", "cursor:otherModels"])
        XCTAssertEqual(windows[0].kind, .pool("cursorModels"))
        XCTAssertEqual(windows[1].percentLeft, 6)
    }

    func testOneMissingPoolLeavesTheOtherIntact() {
        let windows = cursorSummary(cursorModels: nil, otherModels: 40).windows

        XCTAssertEqual(windows.count, 2)
        XCTAssertNil(windows[0].percentLeft)
        XCTAssertNil(windows[0].normalizedProgress)
        XCTAssertEqual(windows[1].percentLeft, 40)
    }

    func testWindowProvidersKeepTheirExistingProjection() {
        let claude = WidgetAllowanceSummary(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentLeft: 64,
            currentResetAt: now,
            weeklyPercentLeft: 53,
            weeklyResetAt: now,
            fetchedAt: now
        )

        XCTAssertEqual(claude.windows.map(\.kind), [.current, .weekly])
        XCTAssertTrue(claude.pools.isEmpty)
    }

    func testSnapshotWrittenBeforePoolsExistedStillDecodes() throws {
        let legacy = Data("""
        {
          "schemaVersion": 2,
          "generatedAt": 781000000,
          "sessions": [],
          "allowances": [
            {
              "provider": "codex",
              "currentWindowLabel": "Weekly",
              "currentPercentLeft": 19,
              "fetchedAt": 781000000
            }
          ],
          "providers": [],
          "attentionCount": 0,
          "activeCount": 0
        }
        """.utf8)

        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: legacy)

        XCTAssertEqual(snapshot.allowances.count, 1)
        XCTAssertTrue(snapshot.allowances[0].pools.isEmpty)
        XCTAssertEqual(snapshot.allowances[0].windows.map(\.label), ["Weekly"])
    }

    func testPoolSnapshotRoundTripsThroughTheSharedContainerEncoding() throws {
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            sessions: [],
            allowances: [cursorSummary(cursorModels: 74, otherModels: 6)],
            providers: [],
            attentionCount: 0,
            activeCount: 0
        )

        let decoded = try JSONDecoder().decode(
            WidgetSnapshot.self,
            from: try JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.allowances[0].pools.map(\.label), ["Cursor Models", "Other Models"])
    }

    /// The snapshot is the widget's whole view of the world, so it must
    /// carry allowance numbers and nothing resembling a credential.
    func testSnapshotCarriesNoCredentialFields() throws {
        let data = try JSONEncoder().encode(
            WidgetSnapshot(
                generatedAt: now,
                sessions: [],
                allowances: [cursorSummary(cursorModels: 74, otherModels: 6)],
                providers: [],
                attentionCount: 0,
                activeCount: 0
            )
        )
        let text = try XCTUnwrap(String(data: data, encoding: .utf8)).lowercased()

        // "sessions" is a legitimate snapshot field; the concern is
        // credential material.
        for forbidden in ["cookie", "token", "authorization", "credential", "workos"] {
            XCTAssertFalse(text.contains(forbidden), "Snapshot must not carry \(forbidden)")
        }
    }

    func testBuilderCarriesPoolsFromTheDomainAllowance() {
        let snapshot = WidgetSnapshotBuilder.build(
            resolved: emptyResolved,
            allowances: [.cursor: domainCursorAllowance()],
            installedProviders: [:],
            now: now
        )

        let labels = snapshot.allowances.first?.pools.map { $0.label }
        XCTAssertEqual(labels, ["Cursor Models", "Other Models"])
    }

    func testAChangedPoolPercentageIsWorthReloadingTheWidgetFor() {
        let before = WidgetSnapshotBuilder.build(
            resolved: emptyResolved,
            allowances: [.cursor: domainCursorAllowance()],
            installedProviders: [:],
            now: now
        )
        let after = WidgetSnapshotBuilder.build(
            resolved: emptyResolved,
            allowances: [.cursor: domainCursorAllowance(otherModels: 99)],
            installedProviders: [:],
            now: now
        )

        XCTAssertTrue(WidgetSnapshotBuilder.isMeaningfullyDifferent(after, from: before))
    }

    func testOneSharedResetIsCollapsedForRepeatFreeCaptions() {
        XCTAssertEqual(
            cursorSummary(cursorModels: 74, otherModels: 6).sharedPoolResetAt,
            now
        )
    }

    func testDifferingPoolResetsAreNeverCollapsed() {
        let summary = WidgetAllowanceSummary(
            provider: .cursor,
            currentWindowLabel: "Billing cycle",
            currentPercentLeft: nil,
            currentResetAt: nil,
            weeklyPercentLeft: nil,
            weeklyResetAt: nil,
            pools: [
                WidgetAllowancePool(id: "a", label: "Cursor Models", percentLeft: 70, resetAt: now),
                WidgetAllowancePool(
                    id: "b",
                    label: "Other Models",
                    percentLeft: 20,
                    resetAt: now.addingTimeInterval(3600)
                )
            ],
            fetchedAt: now
        )

        XCTAssertNil(summary.sharedPoolResetAt)
    }

    func testAMissingPoolResetIsNeverCollapsed() {
        let summary = WidgetAllowanceSummary(
            provider: .cursor,
            currentWindowLabel: "Billing cycle",
            currentPercentLeft: nil,
            currentResetAt: nil,
            weeklyPercentLeft: nil,
            weeklyResetAt: nil,
            pools: [
                WidgetAllowancePool(id: "a", label: "Cursor Models", percentLeft: 70, resetAt: now),
                WidgetAllowancePool(id: "b", label: "Other Models", percentLeft: 20, resetAt: nil)
            ],
            fetchedAt: now
        )

        XCTAssertNil(summary.sharedPoolResetAt)
    }

    func testWindowProvidersNeverCollapseAReset() {
        let claude = WidgetAllowanceSummary(
            provider: .claude,
            currentWindowLabel: "5h",
            currentPercentLeft: 64,
            currentResetAt: now,
            weeklyPercentLeft: 53,
            weeklyResetAt: now,
            fetchedAt: now
        )

        XCTAssertNil(claude.sharedPoolResetAt)
    }

    private var emptyResolved: ResolvedSessions {
        ResolvedSessions(
            sessions: [],
            dominantPhase: .idle,
            activeCount: 0,
            permissionCount: 0,
            activeProviders: []
        )
    }

    private func cursorSummary(
        cursorModels: Double?,
        otherModels: Double?
    ) -> WidgetAllowanceSummary {
        WidgetAllowanceSummary(
            provider: .cursor,
            currentWindowLabel: "Billing cycle",
            currentPercentLeft: nil,
            currentResetAt: nil,
            weeklyPercentLeft: nil,
            weeklyResetAt: nil,
            pools: [
                WidgetAllowancePool(
                    id: "cursorModels",
                    label: "Cursor Models",
                    percentLeft: cursorModels,
                    resetAt: now
                ),
                WidgetAllowancePool(
                    id: "otherModels",
                    label: "Other Models",
                    percentLeft: otherModels,
                    resetAt: now
                )
            ],
            fetchedAt: now
        )
    }

    private func domainCursorAllowance(otherModels: Double = 94) -> ProviderAllowance {
        ProviderAllowance(
            provider: .cursor,
            currentWindowLabel: "Billing cycle",
            currentPercentUsed: nil,
            currentResetAt: nil,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            pools: [
                AllowancePool(id: "cursorModels", label: "Cursor Models", percentUsed: 26, resetAt: now),
                AllowancePool(id: "otherModels", label: "Other Models", percentUsed: otherModels, resetAt: now)
            ],
            fetchedAt: now
        )
    }
}
