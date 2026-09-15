import Foundation

/// The only transport boundary for requests that carry a user-pasted provider
/// session cookie. A redirect is refused before another request can exist, and
/// the completed response must name the exact original HTTPS endpoint.
final class CredentialUsageOriginBoundary: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private static let redirectionStatuses = 300 ... 399

    static func session(configuration: URLSessionConfiguration = .ephemeral) -> URLSession {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(
            configuration: configuration,
            delegate: CredentialUsageOriginBoundary(),
            delegateQueue: nil
        )
    }

    static func holds(response: URLResponse?, endpoint: URL) -> Bool {
        guard let http = response as? HTTPURLResponse,
              !redirectionStatuses.contains(http.statusCode),
              let answered = http.url else {
            return false
        }
        return matches(answered, endpoint)
    }

    private static func matches(_ candidate: URL, _ endpoint: URL) -> Bool {
        candidate.scheme == endpoint.scheme
            && candidate.host == endpoint.host
            && candidate.port == endpoint.port
            && candidate.path == endpoint.path
            && candidate.user == nil
            && candidate.password == nil
            && candidate.query == nil
            && candidate.fragment == nil
    }

    private override init() { super.init() }

    static func redirectRequest(
        response: HTTPURLResponse,
        newRequest: URLRequest
    ) -> URLRequest? {
        nil
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(Self.redirectRequest(response: response, newRequest: request))
    }
}
