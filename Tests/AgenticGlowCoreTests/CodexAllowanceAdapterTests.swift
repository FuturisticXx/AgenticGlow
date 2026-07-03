import Foundation
import XCTest
@testable import AgenticGlowCore

final class CodexAllowanceAdapterTests: XCTestCase {
    func testAdapterNormalizesFixtureFromSupportedLocalAppServer() async throws {
        let data = try fixtureData()
        let requester = StubCodexRateLimitRequester(data: data)
        let adapter = CodexAllowanceAdapter(
            requester: requester,
            now: { Date(timeIntervalSince1970: 1_783_099_000) }
        )

        let allowance = try await adapter.fetch()

        XCTAssertEqual(allowance.currentPercentLeft, 74)
        XCTAssertEqual(allowance.weeklyPercentLeft, 82)
        let count = await requester.requestCount()
        XCTAssertEqual(count, 1)
    }

    func testAppServerWireRequestContainsNoCredentialMaterial() throws {
        let request = CodexAppServerProtocol.rateLimitRequest
        let text = String(decoding: request, as: UTF8.self)

        XCTAssertTrue(text.contains("account/rateLimits/read"))
        XCTAssertTrue(text.contains("initialize"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("authorization"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("password"))
    }

    func testAppServerProtocolExtractsOnlyMatchingResponseLine() throws {
        let fixture = try fixtureData()
        let stream = Data("{\"method\":\"account/rateLimits/updated\",\"params\":{}}\n".utf8)
            + fixture + Data("\n".utf8)

        XCTAssertEqual(try CodexAppServerProtocol.extractRateLimitResponse(from: stream), fixture)
    }

    func testAppServerProtocolPreservesProviderRetryGuidance() {
        let response = Data(
            "{\"id\":7,\"error\":{\"code\":429,\"message\":\"rate limited\",\"data\":{\"retryAfterSeconds\":120}}}\n".utf8
        )

        XCTAssertThrowsError(
            try CodexAppServerProtocol.extractRateLimitResponse(from: response)
        ) { error in
            XCTAssertEqual(error as? AllowanceAdapterError, .rateLimited(retryAfter: 120))
        }
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "codex-rate-limits", withExtension: "json")
        )
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

private actor StubCodexRateLimitRequester: CodexRateLimitRequesting {
    private let data: Data
    private var count = 0

    init(data: Data) { self.data = data }

    func readRateLimits() async throws -> Data {
        count += 1
        return data
    }

    func requestCount() -> Int { count }
}
