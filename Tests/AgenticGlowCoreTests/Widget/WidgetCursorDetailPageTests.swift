import Foundation
import XCTest
@testable import AgenticGlowCore

/// The temporary Cursor page: what the default view carries, what the
/// detail page carries, and every way the detail page has to resolve back
/// to the default one.
final class WidgetCursorDetailPageTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    // MARK: - Default page

    func testCursorUsageOffLeavesTheOverviewExactlyAsItWas() {
        let snapshot = snapshot(includingCursor: false)

        XCTAssertEqual(snapshot.overviewAllowances.map(\.provider), [.codex, .claude])
        XCTAssertEqual(
            snapshot.overviewAllowances.flatMap(\.windows).map(\.label),
            ["5h", "Weekly", "5h", "Weekly"]
        )
        XCTAssertTrue(snapshot.poolAllowances.isEmpty, "No detail control without Cursor data")
    }

    func testCursorUsageOnDoesNotChangeTheOverview() {
        let withCursor = snapshot(includingCursor: true)

        XCTAssertEqual(withCursor.overviewAllowances.map(\.provider), [.codex, .claude])
        XCTAssertEqual(
            withCursor.overviewAllowances.flatMap(\.windows).map(\.label),
            snapshot(includingCursor: false).overviewAllowances.flatMap(\.windows).map(\.label)
        )
    }

    func testCursorBarsAreAbsentFromTheOverviewButAvailableAsAPage() {
        let snapshot = snapshot(includingCursor: true)

        let overviewLabels = snapshot.overviewAllowances.flatMap(\.windows).map(\.label)
        XCTAssertFalse(overviewLabels.contains("Cursor Models"))
        XCTAssertFalse(overviewLabels.contains("Other Models"))
        XCTAssertEqual(snapshot.poolAllowances.map(\.provider), [.cursor])
    }

    // MARK: - Detail page

    func testActivationShowsTheCursorPage() {
        let state = WidgetDetailState.showingCursorDetail(from: now)

        XCTAssertEqual(
            WidgetDetailPresentation.page(state: state, snapshot: snapshot(includingCursor: true), now: now),
            .cursorDetail
        )
    }

    func testCursorPageCarriesBothPoolsAndNoCombinedFigure() throws {
        let cursor = try XCTUnwrap(snapshot(includingCursor: true).poolAllowances.first)

        XCTAssertEqual(cursor.windows.map(\.label), ["Cursor Models", "Other Models"])
        XCTAssertEqual(cursor.windows.map(\.percentLeft), [74, 6])
        XCTAssertNil(cursor.currentPercentLeft)
        XCTAssertNil(cursor.weeklyPercentLeft)
    }

    func testAnUnavailablePoolStaysUnavailableOnTheDetailPage() {
        let cursor = cursorSummary(cursorModels: nil, otherModels: 6)

        XCTAssertNil(cursor.windows[0].percentLeft)
        XCTAssertNil(cursor.windows[0].normalizedProgress)
        XCTAssertEqual(cursor.windows[1].percentLeft, 6)
    }

    // MARK: - Expiry

    func testTheDefaultDurationIsTwelveSeconds() {
        XCTAssertEqual(WidgetDetailState.cursorDetailDuration, 12)
        XCTAssertEqual(
            WidgetDetailState.showingCursorDetail(from: now).cursorDetailUntil,
            now.addingTimeInterval(12)
        )
    }

    func testTheOverviewReturnsAtTheExpiryMoment() {
        let state = WidgetDetailState.showingCursorDetail(from: now)

        XCTAssertEqual(
            WidgetDetailPresentation.overviewReturnsAt(
                state: state,
                snapshot: snapshot(includingCursor: true),
                now: now
            ),
            now.addingTimeInterval(12)
        )
    }

    func testAnExpiredPageResolvesToTheOverview() {
        let state = WidgetDetailState.showingCursorDetail(from: now)
        let later = now.addingTimeInterval(13)

        XCTAssertEqual(
            WidgetDetailPresentation.page(
                state: state,
                snapshot: snapshot(includingCursor: true),
                now: later
            ),
            .overview
        )
        XCTAssertNil(
            WidgetDetailPresentation.overviewReturnsAt(
                state: state,
                snapshot: snapshot(includingCursor: true),
                now: later
            )
        )
    }

    /// A reload arriving long after the request must not resurrect the
    /// page: the state is a deadline, not a flag.
    func testTheDetailPageCannotBecomeStuck() {
        let state = WidgetDetailState.showingCursorDetail(from: now)

        for offset in [12.0, 60.0, 3_600.0, 86_400.0] {
            XCTAssertEqual(
                WidgetDetailPresentation.page(
                    state: state,
                    snapshot: snapshot(includingCursor: true),
                    now: now.addingTimeInterval(offset)
                ),
                .overview,
                "Stuck \(offset)s after activation"
            )
        }
    }

    func testDisablingCursorWhileTheDetailPageIsUpRestoresTheOverview() {
        let state = WidgetDetailState.showingCursorDetail(from: now)

        XCTAssertEqual(
            WidgetDetailPresentation.page(
                state: state,
                snapshot: snapshot(includingCursor: false),
                now: now
            ),
            .overview
        )
    }

    func testTheReturnControlClearsTheStateImmediately() {
        XCTAssertEqual(
            WidgetDetailPresentation.page(
                state: .empty,
                snapshot: snapshot(includingCursor: true),
                now: now
            ),
            .overview
        )
    }

    // MARK: - Storage

    func testStateRoundTripsThroughTheSharedContainer() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppGroupDetailStateStore(containerDirectory: { directory })

        XCTAssertEqual(store.load(), .empty, "A missing file must read as the overview")

        store.save(.showingCursorDetail(from: now))
        XCTAssertEqual(store.load().cursorDetailUntil, now.addingTimeInterval(12))

        store.save(.empty)
        XCTAssertEqual(store.load(), .empty)
    }

    func testAnUnreadableStateFileFailsTowardTheOverview() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not json".utf8).write(
            to: directory.appendingPathComponent(AppGroupDetailStateStore.filename)
        )

        XCTAssertEqual(AppGroupDetailStateStore(containerDirectory: { directory }).load(), .empty)
    }

    /// The page state is presentation only. Nothing about the account or
    /// the credential may travel with it.
    func testStateCarriesNothingButAnExpiryDate() throws {
        let data = try JSONEncoder.agenticglow.encode(WidgetDetailState.showingCursorDetail(from: now))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8)).lowercased()

        for forbidden in ["cookie", "token", "authorization", "credential", "workos", "percent"] {
            XCTAssertFalse(text.contains(forbidden), "Detail state must not carry \(forbidden)")
        }
    }

    // MARK: - Fixtures

    private func snapshot(includingCursor: Bool) -> WidgetSnapshot {
        var allowances = [
            windowSummary(provider: .codex),
            windowSummary(provider: .claude)
        ]
        if includingCursor {
            allowances.append(cursorSummary(cursorModels: 74, otherModels: 6))
        }
        return WidgetSnapshot(
            generatedAt: now,
            sessions: [],
            allowances: allowances,
            providers: [],
            attentionCount: 0,
            activeCount: 0
        )
    }

    private func windowSummary(provider: AgentProvider) -> WidgetAllowanceSummary {
        WidgetAllowanceSummary(
            provider: provider,
            currentWindowLabel: "5h",
            currentPercentLeft: 45,
            currentResetAt: now.addingTimeInterval(3600),
            weeklyPercentLeft: 71,
            weeklyResetAt: now.addingTimeInterval(4 * 86_400),
            fetchedAt: now
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
                    resetAt: now.addingTimeInterval(9 * 86_400)
                ),
                WidgetAllowancePool(
                    id: "otherModels",
                    label: "Other Models",
                    percentLeft: otherModels,
                    resetAt: now.addingTimeInterval(9 * 86_400)
                )
            ],
            fetchedAt: now
        )
    }
}
