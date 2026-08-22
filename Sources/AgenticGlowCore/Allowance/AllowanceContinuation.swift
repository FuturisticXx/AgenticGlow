import Foundation

/// Quiet factual line under popover allowance bars. Appears only when a
/// known Claude or Codex window is below 10% or at 0%. Never names Cursor.
public enum AllowanceContinuation {
    public static func line(allowances: [AgentProvider: ProviderAllowance]) -> String? {
        let known: [AgentProvider] = [.claude, .codex]
        var constrained: [String] = []
        var healthy: [String] = []

        for provider in known {
            guard let allowance = allowances[provider] else { continue }
            let windows = knownWindows(in: allowance)
            let low = windows.filter { $0.percentLeft < AllowanceWarning.thresholdPercentLeft }
            if low.isEmpty {
                if let leftover = windows.first {
                    healthy.append("\(provider.displayName) \(percent(leftover.percentLeft))% left")
                }
            } else {
                for window in low {
                    constrained.append(constrainedClause(provider: provider, window: window))
                }
            }
        }

        guard !constrained.isEmpty else { return nil }
        return (constrained + healthy).joined(separator: ". ")
    }

    private static func constrainedClause(
        provider: AgentProvider,
        window: AllowanceWarning.Window
    ) -> String {
        "\(provider.displayName) \(windowWord(window.label)) \(percent(window.percentLeft))% left"
    }

    private static func windowWord(_ label: String) -> String {
        let lowered = label.lowercased()
        if lowered == "week" || lowered == "weekly" { return "weekly" }
        return label
    }

    private static func knownWindows(in allowance: ProviderAllowance) -> [AllowanceWarning.Window] {
        var windows: [AllowanceWarning.Window] = []
        if let left = allowance.currentPercentLeft {
            windows.append(AllowanceWarning.Window(
                label: allowance.currentWindowLabel,
                percentLeft: left,
                resetAt: allowance.currentResetAt
            ))
        }
        if let left = allowance.weeklyPercentLeft {
            let weeklyIsSameAsCurrent = allowance.currentWindowLabel.lowercased() == "weekly"
                || allowance.currentWindowLabel.lowercased() == "week"
            if !weeklyIsSameAsCurrent || allowance.currentPercentLeft == nil {
                windows.append(AllowanceWarning.Window(
                    label: "week",
                    percentLeft: left,
                    resetAt: allowance.weeklyResetAt
                ))
            }
        }
        return windows
    }

    private static func percent(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
