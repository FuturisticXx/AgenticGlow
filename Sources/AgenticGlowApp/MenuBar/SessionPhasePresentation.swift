import AppKit
import SwiftUI
import AgenticGlowCore

/// Single source of truth for how a SessionPhase renders as an icon and
/// color. The session row and the menu bar icon previously hand-rolled their
/// own tables and had silently drifted apart (idle and working shared one
/// menu bar glyph, while the row used a third, different glyph for each).
/// Both surfaces now read from here.
///
/// Row and menu bar glyphs are allowed to differ deliberately: the row can
/// afford a distinct shape per state at list-row size, while the menu bar
/// icon is tuned for legibility and animation stability at 16-18pt (see
/// StatusItemController). Recording both tables in one place, rather than
/// two separate files, is what keeps them from drifting further.
enum SessionPhasePresentation {
    enum Context {
        case row
        case menuBar
    }

    static func symbolName(
        for phase: SessionPhase,
        toolCategory: ToolCategory? = nil,
        in context: Context
    ) -> String {
        switch context {
        case .row:
            if phase == .usingTool, let toolCategory {
                return categorySymbolName(for: toolCategory)
            }
            return switch phase {
            case .permission: "exclamationmark.circle.fill"
            case .completed: "checkmark.circle.fill"
            case .disconnected: "bolt.slash.circle"
            case .failed: "xmark.circle.fill"
            case .idle: "circle"
            case .thinking, .usingTool: "sparkle"
            }
        case .menuBar:
            return switch phase {
            case .permission: "exclamationmark.circle.fill"
            case .completed: "checkmark.circle.fill"
            case .disconnected: "bolt.slash.circle"
            case .failed: "xmark.circle.fill"
            case .idle, .thinking, .usingTool: "circle.hexagongrid"
            }
        }
    }

    /// Only used on the row: the menu bar icon stays a flat glyph per state
    /// regardless of what tool is running, per its own tuning constraints.
    private static func categorySymbolName(for category: ToolCategory) -> String {
        switch category {
        case .read: "doc.text"
        case .edit: "pencil"
        case .search: "magnifyingglass"
        case .browse: "globe"
        case .command: "terminal"
        case .delegate: "arrow.triangle.branch"
        case .other: "sparkle"
        }
    }

    /// `.thinking` and `.usingTool` return `.controlAccentColor`, a fallback
    /// only: both surfaces actually tint those states with ProviderColor
    /// (per-session on the row, per-frame cross-fade on the menu bar), never
    /// this flat phase color.
    static func nsColor(for phase: SessionPhase) -> NSColor {
        switch phase {
        case .permission: .systemYellow
        case .completed: .systemGreen
        case .disconnected: .secondaryLabelColor
        case .failed: .systemRed
        case .idle: .labelColor
        case .thinking, .usingTool: .controlAccentColor
        }
    }

    static func color(for phase: SessionPhase) -> Color {
        Color(nsColor: nsColor(for: phase))
    }
}
