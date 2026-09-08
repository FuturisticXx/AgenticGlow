import AgenticGlowCore

/// Splits the allowance section into the providers shown at a glance and
/// the ones parked behind a disclosure chevron.
///
/// Codex and Claude are the primary at-a-glance view; anything else is an
/// "additional usage provider" and stays collapsed until asked for. Cursor
/// is the first such provider, not necessarily the last, so the split is
/// expressed as a list rather than a Cursor flag. The control is
/// provider-neutral for the same reason: it carries no provider name.
struct AdditionalUsageDisclosure {
    /// Providers presented behind the chevron, in display order.
    static let additionalProviders: [AgentProvider] = [.cursor]

    /// Providers always shown, in display order.
    static let primaryProviderOrder: [AgentProvider] = AgentProvider.allCases
        .filter { !additionalProviders.contains($0) }

    /// Primary providers with usage turned on.
    let primary: [AgentProvider]
    /// Additional providers with usage turned on. Empty means the chevron
    /// has nothing to reveal, so it is not offered at all.
    let additional: [AgentProvider]

    init(isOn: (AgentProvider) -> Bool) {
        primary = Self.primaryProviderOrder.filter(isOn)
        additional = Self.additionalProviders.filter(isOn)
    }

    var hasAdditionalUsage: Bool { !additional.isEmpty }

    /// The providers rendered for a given disclosure state, in order.
    func visibleProviders(expanded: Bool) -> [AgentProvider] {
        primary + (expanded ? additional : [])
    }

    static func symbolName(expanded: Bool) -> String {
        expanded ? "chevron.up" : "chevron.down"
    }

    static func accessibilityLabel(expanded: Bool) -> String {
        expanded ? "Hide additional usage" : "Show additional usage"
    }
}
