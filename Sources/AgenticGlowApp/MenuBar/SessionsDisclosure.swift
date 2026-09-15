/// The provider-neutral disclosure that parks the Sessions area above the
/// permanent Codex/Claude allowance view.
///
/// This is the mirror image of `AdditionalUsageDisclosure`: optional detail
/// above the anchor, where Cursor and future providers are optional detail
/// below it. The two are deliberately separate types backed by separate view
/// state, so neither toggle can move the other.
///
/// Presentation only. Collapsing hides rows the app already has; it starts no
/// session scan, no allowance fetch, and writes nothing anywhere.
enum SessionsDisclosure {
    /// A freshly presented popover opens with the sessions visible; the
    /// compact allowance-only view is one click away.
    static let defaultExpanded = true

    /// The Sessions region contributes its rows, and therefore its height,
    /// only while expanded. Collapsed it is absent rather than hidden, so the
    /// popover actually contracts instead of reserving the space.
    static func showsSessions(expanded: Bool) -> Bool { expanded }

    static func symbolName(expanded: Bool) -> String {
        expanded ? "chevron.up" : "chevron.down"
    }

    static func accessibilityLabel(expanded: Bool) -> String {
        expanded ? "Hide sessions" : "Show sessions"
    }
}
