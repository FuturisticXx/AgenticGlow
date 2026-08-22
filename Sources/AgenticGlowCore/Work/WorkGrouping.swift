import Foundation

public struct WorkPresentation: Equatable, Sendable {
    public let identity: WorkIdentity
    public let displayName: String
}

public enum WorkGrouping {
    public struct Group: Equatable, Sendable {
        public let presentation: WorkPresentation
        public let sessions: [SessionSnapshot]

        public var representative: SessionSnapshot {
            sessions[0]
        }
    }

    /// Sessions in work-group order so siblings sit together in the popover.
    public static func orderedSessions(from sessions: [SessionSnapshot]) -> [SessionSnapshot] {
        groups(from: sessions).flatMap(\.sessions)
    }

    public static func groups(from sessions: [SessionSnapshot]) -> [Group] {
        var order: [String] = []
        var buckets: [String: [SessionSnapshot]] = [:]
        var identities: [String: WorkIdentity] = [:]

        for session in sessions {
            let identity = WorkIdentity.identity(for: session)
            if buckets[identity.value] == nil {
                order.append(identity.value)
                identities[identity.value] = identity
            }
            buckets[identity.value, default: []].append(session)
        }

        let groups = order.compactMap { key -> Group? in
            guard let identity = identities[key], var members = buckets[key], !members.isEmpty else {
                return nil
            }
            members.sort(by: attentionSort)
            return Group(
                presentation: WorkPresentation(identity: identity, displayName: ""),
                sessions: members
            )
        }
        .sorted(by: groupSort)

        return WorkDisplayName.disambiguate(groups)
    }

    private static func groupSort(_ lhs: Group, _ rhs: Group) -> Bool {
        attentionSort(lhs.representative, rhs.representative)
    }

    static func attentionSort(_ lhs: SessionSnapshot, _ rhs: SessionSnapshot) -> Bool {
        let left = priority(lhs.phase)
        let right = priority(rhs.phase)
        if left != right { return left < right }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.provider != rhs.provider { return lhs.provider.rawValue < rhs.provider.rawValue }
        return lhs.sessionID < rhs.sessionID
    }

    private static func priority(_ phase: SessionPhase) -> Int {
        switch phase {
        case .permission: 0
        case .usingTool: 1
        case .thinking: 2
        case .failed: 3
        case .completed: 4
        case .disconnected: 5
        case .idle: 6
        }
    }
}

public enum WorkDisplayName {
    /// First visible work keeps the folder basename. Later works that
    /// share that basename append the parent folder.
    public static func disambiguate(_ groups: [WorkGrouping.Group]) -> [WorkGrouping.Group] {
        var seen: [String: Int] = [:]
        return groups.map { group in
            let base = baseName(for: group)
            let count = seen[base, default: 0]
            seen[base] = count + 1
            let display: String
            if count == 0 {
                display = base
            } else if let parent = parentName(for: group.presentation.identity), !parent.isEmpty {
                display = "\(base) · \(parent)"
            } else {
                display = base
            }
            return WorkGrouping.Group(
                presentation: WorkPresentation(
                    identity: group.presentation.identity,
                    displayName: display
                ),
                sessions: group.sessions
            )
        }
    }

    private static func baseName(for group: WorkGrouping.Group) -> String {
        let identity = group.presentation.identity
        guard identity.isPath else {
            return group.representative.projectName
        }
        let name = URL(fileURLWithPath: identity.value).lastPathComponent
        if name.isEmpty || name == "/" || name == "." {
            return group.representative.projectName
        }
        return name
    }

    private static func parentName(for identity: WorkIdentity) -> String? {
        guard identity.isPath else { return nil }
        let parent = URL(fileURLWithPath: identity.value).deletingLastPathComponent().lastPathComponent
        if parent.isEmpty || parent == "/" { return nil }
        return parent
    }
}
