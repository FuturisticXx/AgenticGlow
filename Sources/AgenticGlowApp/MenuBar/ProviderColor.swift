import AppKit
import SwiftUI
import AgenticGlowCore

/// Single source of truth for the provider color language: Claude orange,
/// Codex azure, and Cursor teal. When more than one agent is working and
/// Reduce Motion forbids a cross-fade, the icon uses a blended midpoint.
/// Allowance pills and session rows read the popover palette; the menu bar
/// icon picks a palette per bar appearance so it deepens on light
/// wallpapers and brightens on dark ones.
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

    /// Midpoint of the given providers for the active bar appearance.
    /// Used when more than one agent is working but Reduce Motion forbids
    /// the cross-fade.
    static func blend(of providers: [AgentProvider], on bar: BarAppearance) -> NSColor {
        let values = providers.map { barComponents(for: $0, on: bar) }
        guard !values.isEmpty else {
            return nsColor(for: .codex, on: bar)
        }
        let count = Double(values.count)
        return NSColor(
            srgbRed: values.map(\.0).reduce(0, +) / count,
            green: values.map(\.1).reduce(0, +) / count,
            blue: values.map(\.2).reduce(0, +) / count,
            alpha: 1
        )
    }

    /// Static midpoint of Claude orange and Codex azure for the active bar
    /// appearance. Used as the icon tint when both agents are working but
    /// Reduce Motion forbids the cross-fade.
    static func bothBlend(on bar: BarAppearance) -> NSColor {
        blend(of: [.claude, .codex], on: bar)
    }

    private static func components(for provider: AgentProvider) -> (Double, Double, Double) {
        switch provider {
        case .claude: (0.82, 0.37, 0.22)
        case .codex: (0.25, 0.55, 1.00)
        case .cursor: (0.00, 0.70, 0.58)
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
        case (.cursor, .light): (0.00, 0.48, 0.42)
        case (.cursor, .dark): (0.18, 0.82, 0.70)
        }
    }
}
