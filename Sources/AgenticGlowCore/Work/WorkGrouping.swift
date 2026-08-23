import Foundation

public struct WorkPresentation: Equatable, Sendable {
    public let identity: WorkIdentity
    public let displayName: String
}

public enum WorkGrouping {
    public struct Group: Equatable, Sendable {
        public let presentation: WorkPresentation
        /// Logical sessions after same-id adapter reports are collapsed.
        public let sessions: [SessionSnapshot]
        /// Every raw report for this work, including collapsed duplicates.
        public let sourceReports: [SessionSnapshot]

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
            guard let identity = identities[key], let members = buckets[key], !members.isEmpty else {
                return nil
            }
            let displayed = collapseLogicalSessions(members)
            return Group(
                presentation: WorkPresentation(identity: identity, displayName: ""),
                sessions: displayed,
                sourceReports: members
            )
        }
        .sorted(by: groupSort)

        return WorkDisplayName.disambiguate(groups)
    }

    private static func groupSort(_ lhs: Group, _ rhs: Group) -> Bool {
        attentionSort(lhs.representative, rhs.representative)
    }

    /// Same hashed session id in the same work is one conversation reported
    /// by more than one hook adapter. Keep every report; show the owner.
    private static func collapseLogicalSessions(_ members: [SessionSnapshot]) -> [SessionSnapshot] {
        var order: [String] = []
        var byID: [String: [SessionSnapshot]] = [:]
        for session in members {
            if byID[session.sessionID] == nil {
                order.append(session.sessionID)
            }
            byID[session.sessionID, default: []].append(session)
        }
        return order.map { id in
            byID[id]!.sorted(by: ownershipSort)[0]
        }
        .sorted(by: attentionSort)
    }

    static func ownershipSort(_ lhs: SessionSnapshot, _ rhs: SessionSnapshot) -> Bool {
        let left = ownershipRank(lhs)
        let right = ownershipRank(rhs)
        if left != right { return left < right }
        return attentionSort(lhs, rhs)
    }

    /// Lower wins: live process identity, any process identity, native
    /// adapter, then compatibility/secondary hook adapter.
    private static func ownershipRank(_ session: SessionSnapshot) -> (Int, Int, Int) {
        let live = session.sourceBundleID != nil && (session.phase.isActive || session.phase == .permission)
        let identified = session.sourceBundleID != nil
        return (
            live ? 0 : 1,
            identified ? 0 : 1,
            isNativeAdapter(session) ? 0 : 1
        )
    }

    private static func isNativeAdapter(_ session: SessionSnapshot) -> Bool {
        if let bundle = session.sourceBundleID, let owner = nativeProvider(for: bundle) {
            return owner == session.provider
        }
        return session.provider != .claude
    }

    private static func nativeProvider(for bundleID: String) -> AgentProvider? {
        if bundleID == AgentProvider.cursorBundleIdentifier { return .cursor }
        if bundleID == "com.anthropic.claudefordesktop" { return .claude }
        if bundleID == "com.openai.codex" || bundleID == "com.openai.chatgpt" {
            return .codex
        }
        return nil
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
        var stemCounts: [String: Int] = [:]
        for group in groups {
            let stem = WorkTitle.stem(rawBaseName(for: group))
            stemCounts[stem, default: 0] += 1
        }

        var seen: [String: Int] = [:]
        return groups.map { group in
            let raw = rawBaseName(for: group)
            let keepSuffix = stemCounts[WorkTitle.stem(raw), default: 0] > 1
            let base = WorkTitle.display(raw, keepGeneratedSuffix: keepSuffix)
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
                sessions: group.sessions,
                sourceReports: group.sourceReports
            )
        }
    }

    private static func rawBaseName(for group: WorkGrouping.Group) -> String {
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
