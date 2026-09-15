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
        let initialize = String(decoding: CodexAppServerProtocol.initializeRequest, as: UTF8.self)
        let initialized = String(decoding: CodexAppServerProtocol.initializedNotification, as: UTF8.self)
        let rateLimits = String(decoding: CodexAppServerProtocol.rateLimitRequest, as: UTF8.self)
        let text = initialize + initialized + rateLimits

        XCTAssertTrue(text.contains("account/rateLimits/read"))
        XCTAssertTrue(text.contains("initialize"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("authorization"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("password"))
    }

    func testAppServerConversationWaitsForInitializeResponseBeforeRateLimitRequest() throws {
        var conversation = CodexAppServerConversation()

        XCTAssertEqual(conversation.start(), CodexAppServerProtocol.initializeRequest)
        XCTAssertNil(try conversation.receive(Data("{\"method\":\"configWarning\"}\n".utf8)))

        let nextRequest = try XCTUnwrap(
            conversation.receive(Data("{\"id\":1,\"result\":{}}\n".utf8))
        )
        XCTAssertEqual(
            nextRequest,
            CodexAppServerProtocol.initializedNotification + CodexAppServerProtocol.rateLimitRequest
        )
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

    func testClientKeepsInputOpenUntilRateLimitResponseArrives() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("fake-codex")
        let script = """
        #!/usr/bin/python3
        import json, select, sys
        json.loads(sys.stdin.readline())
        print('{"id":1,"result":{}}', flush=True)
        json.loads(sys.stdin.readline())
        request = json.loads(sys.stdin.readline())
        ready, _, _ = select.select([sys.stdin], [], [], 0.2)
        if ready and sys.stdin.read(1) == '':
            sys.exit(2)
        print(json.dumps({"id":request["id"],"result":{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1783244717}}}}), flush=True)
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let client = CodexAppServerClient(executableURL: executable)

        let response = try await client.readRateLimits()

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: response) as? [String: Any]
        )
        XCTAssertEqual((object["id"] as? NSNumber)?.intValue, 7)
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
