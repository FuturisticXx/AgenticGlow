import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class ProviderColorTests: XCTestCase {
    func testPopoverClaudeIsDeepOrange() {
        let c = ProviderColor.nsColor(for: .claude).usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 0.82, accuracy: 0.001)
        XCTAssertEqual(c.greenComponent, 0.37, accuracy: 0.001)
        XCTAssertEqual(c.blueComponent, 0.22, accuracy: 0.001)
    }

    func testPopoverCodexIsAzure() {
        let c = ProviderColor.nsColor(for: .codex).usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 0.25, accuracy: 0.001)
        XCTAssertEqual(c.greenComponent, 0.55, accuracy: 0.001)
        XCTAssertEqual(c.blueComponent, 1.00, accuracy: 0.001)
    }

    func testLightBarUsesDeepPalette() {
        let claude = ProviderColor.nsColor(for: .claude, on: .light).usingColorSpace(.sRGB)!
        XCTAssertEqual(claude.redComponent, 0.82, accuracy: 0.001)
        XCTAssertEqual(claude.greenComponent, 0.37, accuracy: 0.001)
        XCTAssertEqual(claude.blueComponent, 0.22, accuracy: 0.001)
        let codex = ProviderColor.nsColor(for: .codex, on: .light).usingColorSpace(.sRGB)!
        XCTAssertEqual(codex.redComponent, 0.10, accuracy: 0.001)
        XCTAssertEqual(codex.greenComponent, 0.42, accuracy: 0.001)
        XCTAssertEqual(codex.blueComponent, 0.88, accuracy: 0.001)
    }

    func testDarkBarUsesBrightPalette() {
        let claude = ProviderColor.nsColor(for: .claude, on: .dark).usingColorSpace(.sRGB)!
        XCTAssertEqual(claude.redComponent, 0.85, accuracy: 0.001)
        XCTAssertEqual(claude.greenComponent, 0.47, accuracy: 0.001)
        XCTAssertEqual(claude.blueComponent, 0.34, accuracy: 0.001)
        let codex = ProviderColor.nsColor(for: .codex, on: .dark).usingColorSpace(.sRGB)!
        XCTAssertEqual(codex.redComponent, 0.25, accuracy: 0.001)
        XCTAssertEqual(codex.greenComponent, 0.55, accuracy: 0.001)
        XCTAssertEqual(codex.blueComponent, 1.00, accuracy: 0.001)
    }

    func testLightBarPaletteIsDarkerThanDarkBarPalette() {
        for provider in AgentProvider.allCases {
            let light = ProviderColor.nsColor(for: provider, on: .light).usingColorSpace(.sRGB)!
            let dark = ProviderColor.nsColor(for: provider, on: .dark).usingColorSpace(.sRGB)!
            let lightSum = light.redComponent + light.greenComponent + light.blueComponent
            let darkSum = dark.redComponent + dark.greenComponent + dark.blueComponent
            XCTAssertLessThan(
                lightSum, darkSum,
                "\(provider) light-bar color should be deeper than its dark-bar color"
            )
        }
    }

    func testBothBlendIsMidpointOfClaudeAndCodexPerAppearance() {
        for bar in [ProviderColor.BarAppearance.light, .dark] {
            let claude = ProviderColor.nsColor(for: .claude, on: bar).usingColorSpace(.sRGB)!
            let codex = ProviderColor.nsColor(for: .codex, on: bar).usingColorSpace(.sRGB)!
            let blend = ProviderColor.bothBlend(on: bar).usingColorSpace(.sRGB)!
            XCTAssertEqual(blend.redComponent, (claude.redComponent + codex.redComponent) / 2, accuracy: 0.01)
            XCTAssertEqual(blend.greenComponent, (claude.greenComponent + codex.greenComponent) / 2, accuracy: 0.01)
            XCTAssertEqual(blend.blueComponent, (claude.blueComponent + codex.blueComponent) / 2, accuracy: 0.01)
        }
    }
}
