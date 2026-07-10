import AppKit
import SwiftUI
import AgenticGlowCore

/// Single source of truth for the provider color language: Claude orange,
/// Codex azure, and the violet midpoint shown for "both working" when motion
/// is reduced and the tint cannot cross-fade. The allowance pills and session
/// rows read the popover palette; the menu bar icon picks a palette per bar
/// appearance so it deepens on light wallpapers and brightens on dark ones.
enum ProviderColor {
    /// The menu bar's effective appearance behind the status item. macOS
    /// decides this per wallpaper; the controller observes it and re-renders.
    enum BarAppearance {
        case light, dark
    }

    /// Popover palette (session rows, allowance pills).
    static func color(for provider: AgentProvider) -> Color {
        let (r, g, b) = components(for: provider)
        return Color(red: r, green: g, blue: b)
    }

    static func nsColor(for provider: AgentProvider) -> NSColor {
        let (r, g, b) = components(for: provider)
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    /// Menu bar palette: deep colors hold up on light bars, bright colors on
    /// dark bars.
    static func nsColor(for provider: AgentProvider, on bar: BarAppearance) -> NSColor {
        let (r, g, b) = barComponents(for: provider, on: bar)
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    /// Static midpoint of Claude orange and Codex azure for the active bar
    /// appearance. Used as the icon tint when both agents are working but
    /// Reduce Motion forbids the cross-fade.
    static func bothBlend(on bar: BarAppearance) -> NSColor {
        let a = barComponents(for: .claude, on: bar)
        let b = barComponents(for: .codex, on: bar)
        return NSColor(
            srgbRed: (a.0 + b.0) / 2,
            green: (a.1 + b.1) / 2,
            blue: (a.2 + b.2) / 2,
            alpha: 1
        )
    }

    private static func components(for provider: AgentProvider) -> (Double, Double, Double) {
        switch provider {
        case .claude: (0.82, 0.37, 0.22)
        case .codex: (0.25, 0.55, 1.00)
        }
    }

    private static func barComponents(
        for provider: AgentProvider,
        on bar: BarAppearance
    ) -> (Double, Double, Double) {
        switch (provider, bar) {
        case (.claude, .light): (0.82, 0.37, 0.22)
        case (.claude, .dark): (0.85, 0.47, 0.34)
        case (.codex, .light): (0.10, 0.42, 0.88)
        case (.codex, .dark): (0.25, 0.55, 1.00)
        }
    }
}
