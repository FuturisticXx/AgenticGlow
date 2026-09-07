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
