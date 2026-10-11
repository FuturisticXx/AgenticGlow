import Foundation
import XCTest
@testable import AgenticGlowCore

final class UsageResetStateStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testEvidenceSurvivesARoundTrip() throws {
        let store = FileUsageResetStateStore(directory: directory)
        let key = UsageWindowKey(provider: .codex, windowLabel: "5h")
        let observedAt = Date(timeIntervalSince1970: 1_783_099_000)

        try store.save([key: UsageWindowEvidence(availability: .exhausted, observedAt: observedAt)])

        let loaded = try store.load()
        XCTAssertEqual(loaded[key]?.availability, .exhausted)
        XCTAssertEqual(
            try XCTUnwrap(loaded[key]).observedAt.timeIntervalSince1970,
            observedAt.timeIntervalSince1970,
            accuracy: 1
        )
    }

    func testMissingFileLoadsEmpty() throws {
        XCTAssertEqual(try FileUsageResetStateStore(directory: directory).load().count, 0)
    }

    func testStateFileIsOwnerReadableOnly() throws {
        let store = FileUsageResetStateStore(directory: directory)
        try store.save([
            UsageWindowKey(provider: .claude, windowLabel: "5h"):
                UsageWindowEvidence(availability: .available, observedAt: Date())
        ])

        let url = directory.appendingPathComponent("usage-reset-state.json")
        let permissions = try FileManager.default
            .attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.int16Value, 0o600)
    }

    func testSavingReplacesRatherThanAppends() throws {
        let store = FileUsageResetStateStore(directory: directory)
        let key = UsageWindowKey(provider: .codex, windowLabel: "5h")

        try store.save([key: UsageWindowEvidence(availability: .exhausted, observedAt: Date())])
        try store.save([key: UsageWindowEvidence(availability: .available, observedAt: Date())])

        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[key]?.availability, .available)
    }
}

final class AllowanceResetWatchPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testExhaustedWindowDueBackSoonIsWatched() {
        XCTAssertTrue(AllowanceRefreshPolicy.isWatchingForReset(
            allowance(currentUsed: 100, currentResetAt: now.addingTimeInterval(120)),
            now: now
        ))
    }

    func testExhaustedWindowDueBackMuchLaterIsNotWatched() {
        // A week-long exhaustion must not be polled every minute for days.
        XCTAssertFalse(AllowanceRefreshPolicy.isWatchingForReset(
            allowance(currentUsed: 100, currentResetAt: now.addingTimeInterval(6 * 86_400)),
            now: now
        ))
    }

    func testOverdueResetKeepsBeingWatched() {
        XCTAssertTrue(AllowanceRefreshPolicy.isWatchingForReset(
            allowance(currentUsed: 100, currentResetAt: now.addingTimeInterval(-3_600)),
            now: now
        ))
    }

    func testExhaustedWindowWithoutAResetTimeIsWatched() {
        XCTAssertTrue(AllowanceRefreshPolicy.isWatchingForReset(
            allowance(currentUsed: 100, currentResetAt: nil),
            now: now
        ))
    }

    func testAvailableWindowIsNotWatched() {
        XCTAssertFalse(AllowanceRefreshPolicy.isWatchingForReset(
            allowance(currentUsed: 40, currentResetAt: now.addingTimeInterval(60)),
            now: now
        ))
    }

    private func allowance(currentUsed: Double, currentResetAt: Date?) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentUsed,
            currentResetAt: currentResetAt,
            weeklyPercentUsed: 10,
            weeklyResetAt: now.addingTimeInterval(6 * 86_400),
            fetchedAt: now
        )
    }
}
