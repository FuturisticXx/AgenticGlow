import Foundation

/// Compact secondary copy for a work group. Single-session work keeps
/// today's phase words so the widget can leave `compactDetail` nil.
public enum WorkStatusLine {
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
        // "N active · names" names only the sessions in that count.
        let active = group.sessions.filter { $0.phase.isActive || $0.phase == .permission }
        let listed = active.isEmpty ? group.sessions : active
        let namePart = compactNamePart(in: listed)
        if !active.isEmpty {
            return namePart.isEmpty ? "\(active.count) active" : "\(active.count) active · \(namePart)"
        }
        return namePart.isEmpty ? "\(group.sessions.count) sessions" : "\(group.sessions.count) · \(namePart)"
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
        ModelDisplayName.display(model)
    }

    private static func compactNamePart(in sessions: [SessionSnapshot]) -> String {
        struct Item {
            let model: String?
            let harness: String
        }

        let items = sessions.map { session in
            Item(
                model: ModelDisplayName.display(session.model),
                harness: session.provider.displayName
            )
        }
        let harnesses = Set(items.map(\.harness))

        if harnesses.count == 1, let harness = harnesses.first {
            var models: [String] = []
            var seen = Set<String>()
            for item in items {
                let name = item.model ?? harness
                if seen.insert(name).inserted {
                    models.append(name)
                }
            }
            let uniqueModels = models.filter { $0 != harness }
            if uniqueModels.isEmpty {
                return harness
            }
            return "\(uniqueModels.joined(separator: ", ")) · \(harness)"
        }

        var parts: [String] = []
        var seen = Set<String>()
        for item in items {
            let text: String
            if let model = item.model, model != item.harness {
                text = "\(model) (\(item.harness))"
            } else {
                text = item.harness
            }
            if seen.insert(text).inserted {
                parts.append(text)
            }
        }
        return parts.joined(separator: ", ")
    }
}
