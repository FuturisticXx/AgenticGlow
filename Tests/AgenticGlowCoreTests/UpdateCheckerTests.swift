import XCTest
@testable import AgenticGlowCore

final class UpdateCheckerTests: XCTestCase {
    func testDisabledAutomaticCheckDoesNotStartNetworkRequest() async throws {
        let transport = RecordingUpdateTransport(response: .init(tagName: "v9.9.9", htmlURL: URL(string: "https://example.com")!))
        let checker = GitHubUpdateChecker(transport: transport)
        let result = try await checker.check(currentVersion: "0.1.0", enabled: false)
        XCTAssertNil(result)
        let requestCount = await transport.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testNewerSemanticVersionReturnsRelease() async throws {
        let transport = RecordingUpdateTransport(response: .init(tagName: "v0.2.0", htmlURL: URL(string: "https://example.com")!))
        let checker = GitHubUpdateChecker(transport: transport)
        let result = try await checker.check(currentVersion: "0.1.0", enabled: true)
        XCTAssertEqual(result?.version, "0.2.0")
    }
}

private actor RecordingUpdateTransport: UpdateTransporting {
    let response: ReleaseMetadata
    private(set) var requestCount = 0

    init(response: ReleaseMetadata) {
        self.response = response
    }

    func latestRelease() async throws -> ReleaseMetadata {
        requestCount += 1
        return response
    }
}
