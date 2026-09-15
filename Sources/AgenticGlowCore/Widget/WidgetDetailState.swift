import Foundation

/// Which allowance page the widget is showing.
///
/// The default page is the Codex and Claude overview the widget has always
/// shown. A provider that reports sub-pools (Cursor) is deliberately not
/// part of it: two more bars crowd a fixed canvas, so its pools live on
/// their own temporary page reached from a small control.
public enum WidgetAllowancePage: String, Codable, Equatable, Sendable {
    case overview
    case cursorDetail
}

/// The widget's temporary presentation state, shared through the App Group
/// container. Presentation only: it carries a single expiry date and never
/// any credential, account identity, or usage value.
public struct WidgetDetailState: Codable, Equatable, Sendable {
    /// How long the Cursor page stays up before the overview returns on
    /// its own. WidgetKit renders a timeline entry at this moment, so the
    /// return needs no timer, no polling, and no wake-up.
    public static let cursorDetailDuration: TimeInterval = 12

    public static let empty = WidgetDetailState(cursorDetailUntil: nil)

    public let cursorDetailUntil: Date?

    public init(cursorDetailUntil: Date?) {
        self.cursorDetailUntil = cursorDetailUntil
    }

    public static func showingCursorDetail(from now: Date) -> WidgetDetailState {
        WidgetDetailState(cursorDetailUntil: now.addingTimeInterval(cursorDetailDuration))
    }
}

/// Resolves the stored state, the snapshot, and the current time into the
/// page to render and the moment the widget must be redrawn.
///
/// Every path that isn't an unexpired request for a Cursor page with
/// Cursor data behind it resolves to the overview, so the detail page
/// cannot be entered without data, cannot outlive its expiry, and cannot
/// survive Cursor being switched off.
public enum WidgetDetailPresentation {
    public static func page(
        state: WidgetDetailState,
        snapshot: WidgetSnapshot,
        now: Date
    ) -> WidgetAllowancePage {
        guard
            let until = state.cursorDetailUntil,
            until > now,
            !snapshot.poolAllowances.isEmpty
        else { return .overview }
        return .cursorDetail
    }

    /// When the overview must come back, or nil when it is already showing.
    /// The timeline carries a second entry at this date, which is how the
    /// page reverts without anything running in between.
    public static func overviewReturnsAt(
        state: WidgetDetailState,
        snapshot: WidgetSnapshot,
        now: Date
    ) -> Date? {
        guard page(state: state, snapshot: snapshot, now: now) == .cursorDetail else { return nil }
        return state.cursorDetailUntil
    }
}
