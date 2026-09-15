import Foundation
import XCTest
@testable import AgenticGlowCore

final class CredentialUsageOriginBoundaryTests: XCTestCase {
    func testBoundaryAcceptsOnlyTheExactHTTPSUsageEndpoint() throws {
        let endpoint = try XCTUnwrap(URL(string: "https://claude.ai/api/organizations/org-id/usage"))

        XCTAssertTrue(CredentialUsageOriginBoundary.holds(
            response: response("https://claude.ai/api/organizations/org-id/usage"),
            endpoint: endpoint
        ))

        for candidate in [
            "http://claude.ai/api/organizations/org-id/usage",
            "https://untrusted.example/api/organizations/org-id/usage",
            "https://claude.ai:8443/api/organizations/org-id/usage",
            "https://claude.ai/api/organizations/other-org/usage",
            "https://user:password@claude.ai/api/organizations/org-id/usage",
            "https://claude.ai/api/organizations/org-id/usage?next=elsewhere",
            "https://claude.ai/api/organizations/org-id/usage#fragment"
        ] {
            XCTAssertFalse(
                CredentialUsageOriginBoundary.holds(response: response(candidate), endpoint: endpoint),
                "The boundary admitted \(candidate)"
            )
        }

        XCTAssertFalse(CredentialUsageOriginBoundary.holds(
            response: response("https://claude.ai/api/organizations/org-id/usage", statusCode: 302),
            endpoint: endpoint
        ))
    }

    func testBoundaryRefusesEveryRedirectBeforeACookieBearingRequestCanReachTheTarget() throws {
        let claudeCookie = "sessionKey=synthetic; lastActiveOrg=org-id"
        let cursorCookie = "WorkosCursorSessionToken=synthetic"
        let endpoints = [
            try XCTUnwrap(ClaudeWebUsageClient.makeRequest(sessionCookie: claudeCookie).url),
            try XCTUnwrap(CursorWebUsageClient.makeRequest(sessionCookie: cursorCookie).url)
        ]

        for endpoint in endpoints {
            for (statusCode, target) in [
                (301, "https://untrusted.example/usage"),
                (302, "http://\(endpoint.host ?? "localhost")/usage"),
                (303, "https://untrusted.example/usage"),
                (307, "http://\(endpoint.host ?? "localhost")/usage"),
                (308, "https://untrusted.example/usage")
            ] {
                let targetURL = try XCTUnwrap(URL(string: target))
                let response = try XCTUnwrap(response(endpoint.absoluteString, statusCode: statusCode))
                var redirectedRequest = URLRequest(url: targetURL)
                redirectedRequest.setValue("synthetic-cookie", forHTTPHeaderField: "Cookie")

                XCTAssertNil(
                    CredentialUsageOriginBoundary.redirectRequest(
                        response: response,
                        newRequest: redirectedRequest
                    ),
                    "The boundary admitted \(statusCode) to \(target)"
                )
            }
        }
    }

    func testClaudeAndCursorRejectAFinalResponseFromAnotherOrigin() async throws {
        let claudeCookie = "sessionKey=synthetic; lastActiveOrg=org-id"
        let cursorCookie = "WorkosCursorSessionToken=synthetic"
        let cases: [(URLRequest, String, (URLSession) async throws -> Data)] = [
            (
                try ClaudeWebUsageClient.makeRequest(sessionCookie: claudeCookie),
                claudeCookie,
                { session in
                    try await ClaudeWebUsageClient(session: session).fetchUsage(sessionCookie: claudeCookie)
                }
            ),
            (
                try CursorWebUsageClient.makeRequest(sessionCookie: cursorCookie),
                cursorCookie,
                { session in
                    try await CursorWebUsageClient(session: session).fetchUsage(sessionCookie: cursorCookie)
                }
            )
        ]

        for (request, _, fetch) in cases {
            let origin = try XCTUnwrap(request.url)
            let wrongOrigin = try XCTUnwrap(URL(string: "https://untrusted.example/usage"))
            RedirectProbeURLProtocol.configure(origin: origin, behavior: .response(from: wrongOrigin))
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [RedirectProbeURLProtocol.self]

            do {
                _ = try await fetch(URLSession(configuration: configuration))
                XCTFail("Expected a final-origin refusal")
            } catch {
                XCTAssertFalse(error is CancellationError)
            }
        }
    }

    func testClaudeAndCursorAcceptAResponseFromTheirExactEndpoint() async throws {
        let claudeCookie = "sessionKey=synthetic; lastActiveOrg=org-id"
        let cursorCookie = "WorkosCursorSessionToken=synthetic"
        let cases: [(URLRequest, (URLSession) async throws -> Data)] = [
            (
                try ClaudeWebUsageClient.makeRequest(sessionCookie: claudeCookie),
                { session in
                    try await ClaudeWebUsageClient(session: session).fetchUsage(sessionCookie: claudeCookie)
                }
            ),
            (
                try CursorWebUsageClient.makeRequest(sessionCookie: cursorCookie),
                { session in
                    try await CursorWebUsageClient(session: session).fetchUsage(sessionCookie: cursorCookie)
                }
            )
        ]

        for (request, fetch) in cases {
            let origin = try XCTUnwrap(request.url)
            RedirectProbeURLProtocol.configure(origin: origin, behavior: .response(from: origin))
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [RedirectProbeURLProtocol.self]

            let data = try await fetch(CredentialUsageOriginBoundary.session(configuration: configuration))
            XCTAssertEqual(data, Data("{}".utf8))
            XCTAssertEqual(RedirectProbeURLProtocol.snapshot().originRequests, 1)
        }
    }

    private func response(_ value: String, statusCode: Int = 200) -> HTTPURLResponse? {
        URL(string: value).flatMap {
            HTTPURLResponse(url: $0, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        }
    }
}

private final class RedirectProbeURLProtocol: URLProtocol {
    enum Behavior {
        case response(from: URL)
    }

    struct Snapshot {
        let originRequests: Int
    }

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var origin: URL?
        private var behavior: Behavior?
        private var originRequests = 0

        func configure(origin: URL, behavior: Behavior) {
            lock.lock()
            self.origin = origin
            self.behavior = behavior
            originRequests = 0
            lock.unlock()
        }

        func record(_ request: URLRequest) -> Behavior? {
            lock.lock()
            defer { lock.unlock() }
            guard let url = request.url else { return nil }
            if url == origin {
                originRequests += 1
            }
            return behavior
        }

        func snapshot() -> Snapshot {
            lock.lock()
            defer { lock.unlock() }
            return Snapshot(
                originRequests: originRequests
            )
        }
    }

    private static let state = State()

    static func configure(origin: URL, behavior: Behavior) {
        state.configure(origin: origin, behavior: behavior)
    }

    static func snapshot() -> Snapshot {
        state.snapshot()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let behavior = Self.state.record(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        switch behavior {
        case .response(let responseURL):
            let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
