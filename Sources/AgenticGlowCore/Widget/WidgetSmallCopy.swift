import Foundation

/// Small-family headline. Substitutes a work name only when one overlapping
/// work owns the count. Single-session and multi-work cases stay as today.
public enum WidgetSmallCopy {
    public static func title(for snapshot: WidgetSnapshot) -> String {
        if snapshot.attentionCount > 0 {
            if let name = substitutedWorkName(in: snapshot, owning: { $0.needsAttention }) {
                return name
            }
            return snapshot.attentionCount == 1 ? "1 session" : "\(snapshot.attentionCount) sessions"
        }
        if snapshot.activeCount > 0 {
            if let name = substitutedWorkName(in: snapshot, owning: { $0.phase.isActive }) {
                return name
            }
            return snapshot.activeCount == 1 ? "1 session" : "\(snapshot.activeCount) sessions"
        }
        return "All quiet"
    }

    public static func subtitle(for snapshot: WidgetSnapshot) -> String? {
        if snapshot.attentionCount > 0 {
            return "needs you"
        }
        if snapshot.activeCount > 0 {
            if substitutedWorkName(in: snapshot, owning: { $0.phase.isActive }) != nil {
                return snapshot.activeCount == 1 ? "active" : "\(snapshot.activeCount) active"
            }
            return "active"
        }
        return nil
    }

    private static func substitutedWorkName(
        in snapshot: WidgetSnapshot,
        owning: (WidgetSessionSummary) -> Bool
    ) -> String? {
        let owners = snapshot.sessions.filter(owning)
        guard owners.count == 1, owners[0].compactDetail != nil else { return nil }
        return owners[0].projectName
    }
}
