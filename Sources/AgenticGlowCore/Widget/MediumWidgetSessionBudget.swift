import Foundation

/// How many session rows the medium family shows.
///
/// The desktop keeps its fixed caps: two rows on the overview, one on the
/// Cursor page. The iPhone's medium canvas is shorter once the Mac footer
/// takes the last line, so the overview holds two rows only when no
/// "+ N more" line is needed beside them (otherwise one row plus the
/// summary), and the Cursor page, whose two bars and shared reset line
/// already fill the canvas, shows none. Measured against the iPhone
/// simulator; kept in Core so the rule is testable without rendering.
public enum MediumWidgetSessionBudget {
    public static let maximumRows = 2

    public static func rows(sessionCount: Int, page: WidgetAllowancePage, hasFooter: Bool) -> Int {
        switch (page, hasFooter) {
        case (.overview, false): return maximumRows
        case (.overview, true): return sessionCount <= maximumRows ? maximumRows : 1
        case (.cursorDetail, false): return 1
        case (.cursorDetail, true): return 0
        }
    }
}
