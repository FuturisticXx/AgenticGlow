import Foundation

/// Compact secondary copy for a work group. Single-session work keeps
/// today's phase words so the widget can leave `compactDetail` nil.
public enum WorkStatusLine {
    private static let knownSlugs: [String: String] = [
        "grok": "Grok",
        "claude": "Claude",
        "composer": "Composer"
    ]

    public static func compact(for group: WorkGrouping.Group) -> String {
        if group.sessions.count == 1 {
            return phaseLabel(group.representative.phase)
        }
        switch group.representative.phase {
        case .permission:
            return "Needs you"
        case .failed:
            return "Stopped while working"
        default:
            break
        }
        // "N active · slugs" names only the sessions in that count.
        let active = group.sessions.filter { $0.phase.isActive || $0.phase == .permission }
        let listed = active.isEmpty ? group.sessions : active
        let slugs = sessionSlugs(in: listed)
        let slugPart = slugs.joined(separator: ", ")
        if !active.isEmpty {
            return slugPart.isEmpty ? "\(active.count) active" : "\(active.count) active · \(slugPart)"
        }
        return slugPart.isEmpty ? "\(group.sessions.count) sessions" : "\(group.sessions.count) · \(slugPart)"
    }

    public static func phaseLabel(_ phase: SessionPhase) -> String {
        switch phase {
        case .permission: "Needs you"
        case .usingTool: "Using a tool"
        case .thinking: "Thinking"
        case .failed: "Stopped while working"
        case .completed: "Completed"
        case .disconnected: "Disconnected"
        case .idle: "Idle"
        }
    }

    public static func shortModelName(_ model: String?) -> String? {
        guard let model, !model.isEmpty else { return nil }
        let token = model.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map { String($0).lowercased() }
        if let token, let mapped = knownSlugs[token] {
            return mapped
        }
        return model
    }

    private static func sessionSlugs(in sessions: [SessionSnapshot]) -> [String] {
        let labeled = sessions.map { session -> (slug: String, provider: AgentProvider, fromModel: Bool) in
            if let name = shortModelName(session.model) {
                return (name, session.provider, true)
            }
            return (session.provider.displayName, session.provider, false)
        }

        var seenModelOwners: [String: Set<AgentProvider>] = [:]
        for item in labeled where item.fromModel {
            seenModelOwners[item.slug, default: []].insert(item.provider)
        }

        var result: [String] = []
        var emitted = Set<String>()
        for item in labeled {
            let text: String
            if item.fromModel, (seenModelOwners[item.slug]?.count ?? 0) > 1 {
                text = "\(item.slug) (\(item.provider.displayName))"
            } else {
                text = item.slug
            }
            if emitted.insert(text).inserted {
                result.append(text)
            }
        }
        return result
    }
}
