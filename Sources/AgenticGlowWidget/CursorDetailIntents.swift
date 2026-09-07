import AppIntents
import AgenticGlowCore

/// Opens the temporary Cursor allowance page.
///
/// Runs inside the widget extension, writes one expiry date to the shared
/// App Group container, and returns. WidgetKit reloads the timeline as
/// soon as the intent finishes, which is what redraws the widget; nothing
/// polls or stays resident. The intent handles no usage values and no
/// credential: the Cursor cookie lives in the app's Keychain and never
/// reaches this process.
struct ShowCursorUsageIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Cursor usage"
    static let description = IntentDescription(
        "Briefly show Cursor's Cursor Models and Other Models allowances."
    )
    /// Presentation only; there is nothing to open the app for.
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        AppGroupDetailStateStore().save(.showingCursorDetail(from: Date()))
        return .result()
    }
}

/// Returns to the Codex and Claude overview immediately, without waiting
/// for the page to time out.
struct ReturnToAllowanceOverviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Return to allowance overview"
    static let description = IntentDescription("Show the Codex and Claude allowance overview.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        AppGroupDetailStateStore().save(.empty)
        return .result()
    }
}
