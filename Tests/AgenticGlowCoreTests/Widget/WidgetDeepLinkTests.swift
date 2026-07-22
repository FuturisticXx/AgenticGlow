import Foundation
import XCTest
@testable import AgenticGlowCore

final class WidgetDeepLinkTests: XCTestCase {
    func testOpenAppRoundTrips() {
        let link = WidgetDeepLink.openApp
        XCTAssertEqual(WidgetDeepLink.parse(link.url), link)
    }

    func testOpenSessionRoundTrips() {
        let link = WidgetDeepLink.openSession(provider: .claude, sessionID: "abc-123")
        XCTAssertEqual(WidgetDeepLink.parse(link.url), link)
    }

    func testOpenAppURLUsesTheAgenticglowScheme() {
        XCTAssertEqual(WidgetDeepLink.openApp.url.scheme, "agenticglow")
    }

    func testOpenSessionURLCarriesProviderAndID() {
        let url = WidgetDeepLink.openSession(provider: .codex, sessionID: "sess-9").url
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first { $0.name == "provider" }?.value, "codex")
        XCTAssertEqual(components?.queryItems?.first { $0.name == "id" }?.value, "sess-9")
    }

    func testParseRejectsWrongScheme() {
        let url = URL(string: "https://open")!
        XCTAssertNil(WidgetDeepLink.parse(url))
    }

    func testParseRejectsUnknownHost() {
        let url = URL(string: "agenticglow://somewhere")!
        XCTAssertNil(WidgetDeepLink.parse(url))
    }

    func testParseRejectsSessionLinkMissingProvider() {
        let url = URL(string: "agenticglow://session?id=abc")!
        XCTAssertNil(WidgetDeepLink.parse(url))
    }

    func testParseRejectsSessionLinkMissingID() {
        let url = URL(string: "agenticglow://session?provider=claude")!
        XCTAssertNil(WidgetDeepLink.parse(url))
    }

    func testParseRejectsSessionLinkWithUnknownProvider() {
        let url = URL(string: "agenticglow://session?provider=gemini&id=abc")!
        XCTAssertNil(WidgetDeepLink.parse(url))
    }

    func testParseRejectsSessionLinkWithEmptyID() {
        let url = URL(string: "agenticglow://session?provider=claude&id=")!
        XCTAssertNil(WidgetDeepLink.parse(url))
    }
}
