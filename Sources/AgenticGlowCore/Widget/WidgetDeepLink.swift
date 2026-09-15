import Foundation

/// Pure deep-link model for the widget: what a tap should do, and how to
/// turn that into (and back out of) a URL. Kept separate from the AppKit
/// glue that actually opens the app/session, matching the existing pattern
/// of pure/tested logic plus a thin system-call layer (see
/// CodexWindowScript).
public enum WidgetDeepLink: Equatable, Sendable {
    case openApp
    case openSession(provider: AgentProvider, sessionID: String)

    public static let scheme = "agenticglow"

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .openApp:
            components.host = "open"
        case let .openSession(provider, sessionID):
            components.host = "session"
            components.queryItems = [
                URLQueryItem(name: "provider", value: provider.rawValue),
                URLQueryItem(name: "id", value: sessionID)
            ]
        }
        guard let url = components.url else {
            // scheme/host are fixed ASCII literals; this only happens if a
            // sessionID contains characters URLComponents cannot encode.
            // swiftlint:disable:next force_unwrapping
            return URL(string: "\(Self.scheme)://open")!
        }
        return url
    }

    public static func parse(_ url: URL) -> WidgetDeepLink? {
        guard
            url.scheme == scheme,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        switch components.host {
        case "open":
            return .openApp
        case "session":
            guard
                let providerValue = components.queryItems?.first(where: { $0.name == "provider" })?.value,
                let provider = AgentProvider(rawValue: providerValue),
                let sessionID = components.queryItems?.first(where: { $0.name == "id" })?.value,
                !sessionID.isEmpty
            else { return nil }
            return .openSession(provider: provider, sessionID: sessionID)
        default:
            return nil
        }
    }
}
