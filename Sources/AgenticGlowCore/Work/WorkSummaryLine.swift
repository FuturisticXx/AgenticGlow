import Foundation

/// Popover headline. Names one work only when overlap exists and that
/// work owns the current attention. Otherwise this is today's copy.
public enum WorkSummaryLine {
    public static func popover(resolved: ResolvedSessions) -> String {
        let sessions = resolved.sessions
        let groups = WorkGrouping.groups(from: sessions)

        if resolved.permissionCount >= 1 {
            if let name = overlappingOwnerName(
                of: sessions.filter { $0.phase == .permission },
                in: groups
            ) {
                return "\(name) needs you"
            }
            if resolved.permissionCount == 1 { return "1 agent needs you" }
            return "\(resolved.permissionCount) agents need you"
        }

        if !resolved.activeProviders.isEmpty {
            if let name = overlappingOwnerName(
                of: sessions.filter(\.phase.isActive),
                in: groups
            ) {
                return "\(name) working"
            }
            return providerWorkingCopy(resolved.activeProviders)
        }

        let count = sessions.count
        return count == 1 ? "1 session" : "\(count) sessions"
    }

    /// A display name when every session in `subset` shares one work and
    /// that work has at least two visible sessions.
    private static func overlappingOwnerName(
        of subset: [SessionSnapshot],
        in groups: [WorkGrouping.Group]
    ) -> String? {
        guard !subset.isEmpty else { return nil }
        let owners = Set(subset.map { WorkIdentity.identity(for: $0).value })
        guard owners.count == 1,
              let group = groups.first(where: { $0.presentation.identity.value == owners.first }),
              group.sessions.count > 1
        else { return nil }
        return group.presentation.displayName
    }

    private static func providerWorkingCopy(_ providers: Set<AgentProvider>) -> String {
        let names = AgentProvider.menuBarTintOrder
            .filter { providers.contains($0) }
            .map(\.displayName)
        if names.count <= 2 {
            return "\(names.joined(separator: " and ")) working"
        }
        return "\(names.dropLast().joined(separator: ", ")), and \(names.last!) working"
    }
}
