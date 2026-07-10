import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class ProviderColorTests: XCTestCase {
    func testClaudeIsOrange() {
        let c = ProviderColor.nsColor(for: .claude).usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 0.85, accuracy: 0.001)
        XCTAssertEqual(c.greenComponent, 0.47, accuracy: 0.001)
        XCTAssertEqual(c.blueComponent, 0.34, accuracy: 0.001)
    }

    func testCodexIsAzure() {
        let c = ProviderColor.nsColor(for: .codex).usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 0.25, accuracy: 0.001)
        XCTAssertEqual(c.greenComponent, 0.55, accuracy: 0.001)
        XCTAssertEqual(c.blueComponent, 1.00, accuracy: 0.001)
    }

    func testBothBlendIsMidpointOfClaudeAndCodex() {
        let claude = ProviderColor.nsColor(for: .claude).usingColorSpace(.sRGB)!
        let codex = ProviderColor.nsColor(for: .codex).usingColorSpace(.sRGB)!
        let blend = ProviderColor.bothBlend.usingColorSpace(.sRGB)!
        XCTAssertEqual(blend.redComponent, (claude.redComponent + codex.redComponent) / 2, accuracy: 0.01)
        XCTAssertEqual(blend.greenComponent, (claude.greenComponent + codex.greenComponent) / 2, accuracy: 0.01)
        XCTAssertEqual(blend.blueComponent, (claude.blueComponent + codex.blueComponent) / 2, accuracy: 0.01)
    }
}
