import Foundation

/// One named allowance sub-pool inside a single provider.
///
/// Codex and Claude report time windows (a current window and, for
/// Claude, a weekly one) and carry no pools. Cursor is the first provider
/// whose plan splits into concurrently active allowances that share a
/// reset but have separate denominators, so a percentage from one says
/// nothing about the other. Pools are therefore always carried and
/// displayed individually. They are never summed, averaged, or otherwise
/// combined into a single provider number.
public struct AllowancePool: Codable, Equatable, Sendable, Identifiable {
    /// Stable across releases and independent of the display label, so a
    /// notification's dedupe key and a widget row's identity survive a
    /// copy change.
    public let id: String
    /// Cursor's own name for the pool, shown verbatim in the UI.
    public let label: String
    public let percentUsed: Double?
    public let percentLeft: Double?
    public let resetAt: Date?

    public init(
        id: String,
        label: String,
        percentUsed: Double?,
        resetAt: Date?
    ) {
        self.id = id
        self.label = label
        self.percentUsed = Self.clamp(percentUsed)
        self.percentLeft = Self.clamp(percentUsed).map { 100 - $0 }
        self.resetAt = resetAt
    }

    private static func clamp(_ value: Double?) -> Double? {
        value.map { min(100, max(0, $0)) }
    }
}
