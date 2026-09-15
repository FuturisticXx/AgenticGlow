import SwiftUI
import AgenticGlowCore

/// The same provider brand colors as the app's ProviderColor, but
/// duplicated here as plain SwiftUI constants: ProviderColor lives in the
/// AgenticGlowApp target (AppKit-flavored) and this extension deliberately
/// does not depend on the full app target. This is the one intentional
/// duplication in the widget (3 hex values), not a broader shared module.
enum WidgetColorPalette {
    static let claude = Color(red: 0xD9 / 255, green: 0x78 / 255, blue: 0x57 / 255)
    static let codex = Color(red: 0x40 / 255, green: 0x8C / 255, blue: 0xFF / 255)
    static let cursor = Color(red: 0x00 / 255, green: 0xB3 / 255, blue: 0x94 / 255)

    static func color(for provider: AgentProvider) -> Color {
        switch provider {
        case .claude: claude
        case .codex: codex
        case .cursor: cursor
        }
    }
}
