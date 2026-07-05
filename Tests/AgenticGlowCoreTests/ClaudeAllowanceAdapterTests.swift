import Foundation
import XCTest
@testable import AgenticGlowCore

final class ClaudeAllowanceAdapterTests: XCTestCase {
    func testAdapterNormalizesClaudeUsageFixture() async throws {
        let requester = StubClaudeUsageRequester(data: try fixtureData())
        let adapter = ClaudeAllowanceAdapter(
            sessionCookie: { "sessionKey=secret; lastActiveOrg=org-id" },
            requester: requester,
            now: { Date(timeIntervalSince1970: 1_783_238_400) }
        )

        let allowance = try await adapter.fetch()

        XCTAssertEqual(allowance.provider, .claude)
        XCTAssertEqual(allowance.currentWindowLabel, "5h")
        XCTAssertEqual(allowance.currentPercentUsed, 90)
        XCTAssertEqual(allowance.weeklyPercentUsed, 9)
        XCTAssertNotNil(allowance.currentResetAt)
        XCTAssertNotNil(allowance.weeklyResetAt)
        let receivedCookie = await requester.receivedCookie()
        XCTAssertEqual(receivedCookie, "sessionKey=secret; lastActiveOrg=org-id")
    }

    func testWebClientBuildsOrganizationUsageRequestWithCookieHeader() throws {
        let request = try ClaudeWebUsageClient.makeRequest(
            sessionCookie: "sessionKey=secret; lastActiveOrg=%22org-id%22"
        )

        XCTAssertEqual(request.url?.absoluteString, "https://claude.ai/api/organizations/org-id/usage")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "sessionKey=secret; lastActiveOrg=%22org-id%22")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testWebClientRejectsCookieWithoutOrganization() {
        XCTAssertThrowsError(
            try ClaudeWebUsageClient.makeRequest(sessionCookie: "sessionKey=secret")
        ) { error in
            XCTAssertEqual(
                error as? AllowanceAdapterError,
                .unavailable("Claude session cookie is missing its active organization.")
            )
        }
    }

    func testWebClientMapsUnauthorizedResponseToExpiredCredential() {
        XCTAssertThrowsError(try ClaudeWebUsageClient.validate(statusCode: 401)) { error in
            XCTAssertEqual(
                error as? AllowanceAdapterError,
                .unavailable("Claude session cookie expired. Update Usage Access.")
            )
        }
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "claude-usage",
                withExtension: "json"
            )
        )
        return try Data(contentsOf: url)
    }
}

private actor StubClaudeUsageRequester: ClaudeUsageRequesting {
    private let data: Data
    private var cookie: String?

    init(data: Data) { self.data = data }

    func fetchUsage(sessionCookie: String) async throws -> Data {
        cookie = sessionCookie
        return data
    }

    func receivedCookie() -> String? { cookie }
}
