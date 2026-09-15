import Foundation

/// How much of the large widget's fixed canvas the session list may take.
///
/// Sessions and allowance windows share one non-scrolling canvas, so the
/// session area is bounded by the space left over rather than by how many
/// sessions happen to be running. Everything else is a fixed cost that is
/// never traded away for another session row: the content insets, the
/// four Codex and Claude windows with their captions, and the detail
/// control.
///
/// Measured in points rather than rows because the two things the session
/// area can render cost different amounts, and counting rows alone is
/// what previously pushed the first row off the canvas: a list that
/// overflows also renders a "+ N more" line, so it costs more than a list
/// of the same visible length that does not.
///
/// Calibrated against the installed desktop widget. The budget for the
/// shipping default of four windows deliberately holds a margin: raising
/// the top content inset to match the system's own widgets spent the
/// space a second session row used to occupy.
public struct LargeWidgetSessionLayout: Equatable, Sendable {
    /// Session rows to render.
    public let rows: Int
    /// Sessions folded into the "+ N more" line. Zero means no line.
    public let hiddenCount: Int

    public init(rows: Int, hiddenCount: Int) {
        self.rows = rows
        self.hiddenCount = hiddenCount
    }
}

public enum LargeWidgetSessionBudget {
    /// A detailed session row: two lines of text plus the stack spacing.
    public static let rowHeight: Double = 34
    /// The "+ N more" summary line.
    public static let summaryHeight: Double = 16

    /// Vertical points the session area may spend, after the insets and
    /// the allowance section have taken theirs.
    public static func availablePoints(allowanceWindowCount: Int) -> Double {
        switch allowanceWindowCount {
        case 0...2: 160
        case 3: 90
        case 4: 52
        case 5: 18
        // Three providers with usage on: the allowance section alone
        // fills the canvas and the session area yields entirely. Session
        // state stays available in the menu bar and the smaller families.
        default: 0
        }
    }

    /// What the allowance section below the divider costs on `page`,
    /// expressed in the window count this budget is calibrated in.
    /// Measured per page rather than assumed, so the detail page gets a
    /// budget matching the two bars it actually draws instead of the four
    /// the overview draws.
    public static func allowanceWindowCount(
        snapshot: WidgetSnapshot,
        page: WidgetAllowancePage
    ) -> Int {
        switch page {
        case .overview:
            return snapshot.overviewAllowances.flatMap(\.windows).count
        case .cursorDetail:
            // Two pool bars plus the page's own header row, which costs
            // about what one more window does.
            return (snapshot.poolAllowances.first?.windows.count ?? 0) + 1
        }
    }

    /// The session area's layout for a snapshot on a given page. Here
    /// rather than in the view so the rule stays testable without
    /// rendering anything.
    public static func layout(
        snapshot: WidgetSnapshot,
        page: WidgetAllowancePage
    ) -> LargeWidgetSessionLayout {
        layout(
            sessionCount: snapshot.sessions.count,
            allowanceWindowCount: allowanceWindowCount(snapshot: snapshot, page: page)
        )
    }

    public static func layout(
        sessionCount: Int,
        allowanceWindowCount: Int
    ) -> LargeWidgetSessionLayout {
        let budget = availablePoints(allowanceWindowCount: allowanceWindowCount)
        // Drop a row at a time until what would actually be drawn fits,
        // counting the summary line whenever anything is left over.
        for rows in stride(from: sessionCount, through: 0, by: -1) {
            let hidden = sessionCount - rows
            let height = Double(rows) * rowHeight + (hidden > 0 ? summaryHeight : 0)
            if height <= budget {
                return LargeWidgetSessionLayout(rows: rows, hiddenCount: hidden)
            }
        }
        // Not even the summary fits, so the session area yields entirely.
        return LargeWidgetSessionLayout(rows: 0, hiddenCount: 0)
    }
}

/// Which of the eligible sessions the large widget's session area shows.
///
/// The large canvas has room for fewer session rows than there are
/// sessions to report (one row plus "+ N more" in the shipping four-window
/// configuration), so the rows that do fit take turns instead of the first
/// session owning them forever.
///
/// Selection is presentation only, and it is deliberately not a function
/// of time. It reads the snapshot's own `revision`, so the row advances
/// exactly when the widget naturally receives new data and never in
/// between. That is what keeps this free: it adds no timeline entry, no
/// reload, no timer, and no read of anything the widget was not already
/// holding. It also means the row cannot change without new data, which
/// is why no extra refresh mechanism is needed to drive it.
///
/// It operates on the session list the snapshot already carries, which has
/// been through the app's grouping, deduplication and visibility rules, so
/// a session those rules excluded can never appear here.
public enum LargeWidgetSessionRotation {
    /// Whether taking turns is meaningful at all. A session area showing
    /// every session it has, or showing none, has nothing to rotate.
    public static func rotates(layout: LargeWidgetSessionLayout) -> Bool {
        layout.rows > 0 && layout.hiddenCount > 0
    }

    /// The sessions to draw, in snapshot order, starting at the offset the
    /// snapshot's revision selects and wrapping around the end.
    ///
    /// Ordering is the snapshot's own: the offset changes where a cycle
    /// starts, never the sequence. Any offset is accepted, including one
    /// carried over from a snapshot that had more sessions than this one,
    /// because it is reduced modulo what is actually here. That is what
    /// makes a session list changing underneath a cycle safe rather than
    /// an out-of-range read.
    public static func visibleSessions<Session>(
        _ sessions: [Session],
        offset: Int,
        layout: LargeWidgetSessionLayout
    ) -> [Session] {
        guard layout.rows > 0, !sessions.isEmpty else { return [] }
        let rows = min(layout.rows, sessions.count)
        guard rotates(layout: layout) else { return Array(sessions.prefix(rows)) }
        let start = ((offset % sessions.count) + sessions.count) % sessions.count
        return (0..<rows).map { sessions[(start + $0) % sessions.count] }
    }
}
