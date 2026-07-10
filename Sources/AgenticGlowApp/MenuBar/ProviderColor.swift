import AppKit
import SwiftUI
import AgenticGlowCore

/// Single source of truth for the provider color language: Claude orange,
/// Codex azure, and the violet midpoint shown for "both working" when motion
/// is reduced and the tint cannot cross-fade. The allowance pills, the session
/// row icons, and the menu bar icon all read from here so they stay in step.
enum ProviderColor {
    static func color(for provider: AgentProvider) -> Color {
        let (r, g, b) = components(for: provider)
        return Color(red: r, green: g, blue: b)
    }

    static func nsColor(for provider: AgentProvider) -> NSColor {
        let (r, g, b) = components(for: provider)
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    /// Static midpoint of Claude orange and Codex azure. Used as the icon tint
    /// when both agents are working but Reduce Motion forbids the cross-fade.
    static let bothBlend = NSColor(srgbRed: 0.55, green: 0.51, blue: 0.67, alpha: 1)

    private static func components(for provider: AgentProvider) -> (Double, Double, Double) {
        switch provider {
        case .claude: (0.85, 0.47, 0.34)
        case .codex: (0.25, 0.55, 1.00)
        }
    }
}
