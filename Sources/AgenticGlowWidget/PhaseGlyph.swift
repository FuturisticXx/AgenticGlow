import SwiftUI
import AgenticGlowCore

/// Icon/label/color per session phase, purpose-built for the widget's
/// compact rows. Not shared with the app target's own phase presentation
/// (AppKit-flavored, not importable here); the phase set and meaning is the
/// same, only the presentation is re-expressed for SwiftUI.
enum PhaseGlyph {
    static func symbolName(for phase: SessionPhase, toolCategory: ToolCategory?) -> String {
        switch phase {
        case .permission: "exclamationmark.circle.fill"
        case .usingTool: toolSymbolName(toolCategory)
        case .thinking: "brain"
        case .failed: "xmark.octagon.fill"
        case .completed: "checkmark.circle.fill"
        case .disconnected: "bolt.slash.fill"
        case .idle: "moon.zzz.fill"
        }
    }

    private static func toolSymbolName(_ category: ToolCategory?) -> String {
        switch category {
        case .read: "doc.text.magnifyingglass"
        case .edit: "pencil"
        case .search: "magnifyingglass"
        case .browse: "globe"
        case .command: "terminal"
        case .delegate: "person.2.fill"
        case .other, .none: "sparkle"
        }
    }

    static func label(for phase: SessionPhase) -> String {
        switch phase {
        case .permission: "Needs you"
        case .usingTool: "Using a tool"
        case .thinking: "Thinking"
        case .failed: "Stopped while working"
        case .completed: "Completed"
        case .disconnected: "Disconnected"
        case .idle: "Idle"
        }
    }

    static func color(for phase: SessionPhase) -> Color {
        switch phase {
        case .permission: .yellow
        case .usingTool, .thinking: .accentColor
        case .failed: .red
        case .completed: .green
        case .disconnected, .idle: .secondary
        }
    }
}
