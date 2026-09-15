import Foundation
import XCTest
@testable import AgenticGlowCore

final class CursorAllowanceAdapterTests: XCTestCase {
    private static let fetchedAt = Date(timeIntervalSince1970: 1_783_238_400)
    private let fetchedAt = CursorAllowanceAdapterTests.fetchedAt

    func testAdapterNormalizesBothPoolsFromLiveFixture() async throws {
        let requester = StubCursorUsageRequester(data: try fixtureData())
        let adapter = CursorAllowanceAdapter(
            sessionCookie: { "WorkosCursorSessionToken=secret" },
            requester: requester,
            now: { Self.fetchedAt }
        )

        let allowance = try await adapter.fetch()

        XCTAssertEqual(allowance.provider, .cursor)
        XCTAssertEqual(allowance.pools.count, 2)
        XCTAssertEqual(allowance.pools[0].id, "cursorModels")
        XCTAssertEqual(allowance.pools[0].label, "Cursor Models")
        XCTAssertEqual(allowance.pools[0].percentUsed, 26.4)
        XCTAssertEqual(allowance.pools[1].id, "otherModels")
        XCTAssertEqual(allowance.pools[1].label, "Other Models")
        XCTAssertEqual(allowance.pools[1].percentUsed, 94.2)
        let cookie = await requester.receivedCookie()
        XCTAssertEqual(cookie, "WorkosCursorSessionToken=secret")
    }

    /// The pools are separate allowances with separate denominators. No
    /// combined Cursor number is produced, and the window fields that
    /// would imply one stay empty.
    func testAdapterProducesNoCombinedCursorValue() async throws {
        let allowance = try await normalize(fixtureData())

        XCTAssertNil(allowance.currentPercentUsed)
        XCTAssertNil(allowance.currentPercentLeft)
        XCTAssertNil(allowance.weeklyPercentUsed)
        XCTAssertNil(allowance.weeklyPercentLeft)
        XCTAssertNil(allowance.currentResetAt)
    }

    func testBothPoolsShareTheBillingCycleReset() async throws {
        let allowance = try await normalize(fixtureData())

        let expected = ISO8601DateFormatter().date(from: "2026-09-15T00:00:00Z")
        XCTAssertEqual(allowance.pools[0].resetAt, expected)
        XCTAssertEqual(allowance.pools[1].resetAt, expected)
    }

    func testPercentLeftIsDerivedPerPool() async throws {
        let allowance = try await normalize(fixtureData())

        XCTAssertEqual(try XCTUnwrap(allowance.pools[0].percentLeft), 73.6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(allowance.pools[1].percentLeft), 5.8, accuracy: 0.001)
    }

    func testOnlyCursorModelsReportedKeepsOtherModelsUnknown() async throws {
        let allowance = try await normalize(json("""
        {"individualUsage":{"plan":{"autoPercentUsed":12}}}
        """))

        XCTAssertEqual(allowance.pools[0].percentUsed, 12)
        XCTAssertNil(allowance.pools[1].percentUsed)
        XCTAssertNil(allowance.pools[1].percentLeft)
    }

    func testOnlyOtherModelsReportedKeepsCursorModelsUnknown() async throws {
        let allowance = try await normalize(json("""
        {"individualUsage":{"plan":{"apiPercentUsed":40}}}
        """))

        XCTAssertNil(allowance.pools[0].percentUsed)
        XCTAssertEqual(allowance.pools[1].percentUsed, 40)
    }

    /// A pool genuinely at zero usage is a real reading and must survive.
    func testZeroUsageIsKeptAsARealReading() async throws {
        let allowance = try await normalize(json("""
        {"individualUsage":{"plan":{"autoPercentUsed":0,"apiPercentUsed":100}}}
        """))

        XCTAssertEqual(allowance.pools[0].percentLeft, 100)
        XCTAssertEqual(allowance.pools[1].percentLeft, 0)
    }

    func testMissingBillingCycleLeavesResetUnknownWithoutLosingPools() async throws {
        let allowance = try await normalize(json("""
        {"individualUsage":{"plan":{"autoPercentUsed":10,"apiPercentUsed":20}}}
        """))

        XCTAssertEqual(allowance.pools.count, 2)
        XCTAssertNil(allowance.pools[0].resetAt)
        XCTAssertNil(allowance.pools[1].resetAt)
    }

    func testEpochMillisecondBillingCycleIsAccepted() async throws {
        let allowance = try await normalize(json("""
        {"billingCycleEnd":1789000000000,"individualUsage":{"plan":{"autoPercentUsed":5}}}
        """))

        XCTAssertEqual(allowance.pools[0].resetAt, Date(timeIntervalSince1970: 1_789_000_000))
    }

    func testMalformedPercentagesAreDroppedRatherThanClampedToZero() async throws {
        let allowance = try await normalize(json("""
        {"individualUsage":{"plan":{"autoPercentUsed":-3,"apiPercentUsed":51}}}
        """))

        XCTAssertNil(allowance.pools[0].percentUsed)
        XCTAssertNil(allowance.pools[0].percentLeft)
        XCTAssertEqual(allowance.pools[1].percentUsed, 51)
    }

    func testUnexpectedExtraFieldsDoNotBreakParsing() async throws {
        let allowance = try await normalize(json("""
        {"someNewCursorField":{"nested":true},"individualUsage":{"plan":
        {"autoPercentUsed":8,"apiPercentUsed":9,"futureLane":77}}}
        """))

        XCTAssertEqual(allowance.pools[0].percentUsed, 8)
        XCTAssertEqual(allowance.pools[1].percentUsed, 9)
    }

    func testPlanWithoutEitherPoolIsUnavailableRatherThanZero() async {
        await assertThrows(
            json(#"{"individualUsage":{"plan":{"used":10,"limit":2000}}}"#),
            .unavailable("Cursor did not report usage pools for this plan.")
        )
    }

    func testUnlimitedPlanIsReportedAsHavingNoAllowanceToShow() async {
        await assertThrows(
            json(#"{"isUnlimited":true,"individualUsage":{"plan":{"autoPercentUsed":4}}}"#),
            .unavailable(
                "Cursor reports unlimited usage on this plan, so there is no allowance to show."
            )
        )
    }

    func testMissingCookieAsksForUsageAccessInsteadOfRequesting() async {
        let requester = StubCursorUsageRequester(data: Data())
        let adapter = CursorAllowanceAdapter(
            sessionCookie: { "" },
            requester: requester,
            now: { Self.fetchedAt }
        )

        do {
            _ = try await adapter.fetch()
            XCTFail("Expected a missing-credential failure")
        } catch {
            XCTAssertEqual(
                error as? AllowanceAdapterError,
                .unavailable("Add a Cursor session cookie in Usage Access.")
            )
        }
        let attempted = await requester.receivedCookie()
        XCTAssertNil(attempted, "No request may be made without a credential")
    }

    func testGarbageResponseIsInvalidRatherThanEmptyAllowance() async {
        let requester = StubCursorUsageRequester(data: Data("not json".utf8))
        let adapter = CursorAllowanceAdapter(
            sessionCookie: { "cookie" },
            requester: requester,
            now: { Self.fetchedAt }
        )

        do {
            _ = try await adapter.fetch()
            XCTFail("Expected an invalid-response failure")
        } catch {
            XCTAssertEqual(error as? AllowanceAdapterError, .invalidResponse)
        }
    }

    func testWebClientBuildsReadOnlyUsageSummaryRequestWithCookieHeader() throws {
        let request = try CursorWebUsageClient.makeRequest(sessionCookie: "WorkosCursorSessionToken=abc")

        XCTAssertEqual(request.url?.absoluteString, "https://cursor.com/api/usage-summary")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "WorkosCursorSessionToken=abc")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testExpiredCredentialIsDistinctFromExhaustedAllowance() {
        for status in [401, 403] {
            XCTAssertThrowsError(try CursorWebUsageClient.validate(statusCode: status)) { error in
                XCTAssertEqual(
                    error as? AllowanceAdapterError,
                    .unavailable("Cursor session cookie expired. Update Usage Access.")
                )
            }
        }
    }

    func testRateLimitAndServerFailureMapToTheirOwnStates() {
        XCTAssertThrowsError(try CursorWebUsageClient.validate(statusCode: 429)) { error in
            XCTAssertEqual(error as? AllowanceAdapterError, .rateLimited(retryAfter: nil))
        }
        XCTAssertThrowsError(try CursorWebUsageClient.validate(statusCode: 500)) { error in
            XCTAssertEqual(
                error as? AllowanceAdapterError,
                .unavailable("Cursor usage is temporarily unavailable.")
            )
        }
        XCTAssertNoThrow(try CursorWebUsageClient.validate(statusCode: 200))
    }

    // MARK: - Helpers

    private func normalize(_ data: Data) async throws -> ProviderAllowance {
        try CursorAllowanceNormalizer.normalize(data, fetchedAt: fetchedAt)
    }

    private func assertThrows(
        _ data: Data,
        _ expected: AllowanceAdapterError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try CursorAllowanceNormalizer.normalize(data, fetchedAt: fetchedAt)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? AllowanceAdapterError, expected, file: file, line: line)
        }
    }

    private func json(_ text: String) -> Data {
        Data(text.utf8)
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "cursor-usage-summary",
                withExtension: "json"
            )
        )
        return try Data(contentsOf: url)
    }
}

private actor StubCursorUsageRequester: CursorUsageRequesting {
    private let data: Data
    private var cookie: String?

    init(data: Data) {
        self.data = data
    }

    func fetchUsage(sessionCookie: String) async throws -> Data {
        cookie = sessionCookie
        return data
    }

    func receivedCookie() -> String? { cookie }
}
