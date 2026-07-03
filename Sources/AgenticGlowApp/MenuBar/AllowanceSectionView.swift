import AgenticGlowCore
import SwiftUI

struct AllowanceSectionView: View {
    @Bindable var model: AppModel
    let usageEnabled: Bool
    let enable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALLOWANCE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if !usageEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage access is off")
                        .font(.subheadline.weight(.medium))
                    Text("No provider requests are being made.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Enable…", action: enable)
                        .accessibilityLabel("Enable usage access")
                }
            } else {
                ForEach(AgentProvider.allCases, id: \.rawValue) { provider in
                    if model.allowanceState(for: provider) != .off {
                        ProviderAllowanceRow(
                            provider: provider,
                            state: model.allowanceState(for: provider)
                        )
                    }
                }
            }
        }
    }
}

private struct ProviderAllowanceRow: View {
    let provider: AgentProvider
    let state: AllowanceAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(provider == .codex ? "Codex" : "Claude")
                .font(.subheadline.weight(.semibold))
            switch state {
            case .off:
                EmptyView()
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading usage…").foregroundStyle(.secondary)
                }
                .font(.caption)
            case let .unavailable(reason):
                Label("Unavailable", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(providerName) usage unavailable. \(reason)")
                    .accessibilityIdentifier("AgenticGlow.Allowance.\(provider.rawValue).Unavailable")
            case let .available(allowance, freshness):
                allowanceContent(allowance, freshness: freshness)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func allowanceContent(
        _ allowance: ProviderAllowance,
        freshness: AllowanceFreshness
    ) -> some View {
        let presentation = AllowancePresentation(allowance: allowance, now: Date())
        Text(presentation.currentValue)
            .font(.callout.weight(.medium))
            .monospacedDigit()
        Text(presentation.currentDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
        ProgressView(value: presentation.currentProgress)
            .tint(provider == .codex ? .blue : .purple)
            .accessibilityLabel(presentation.accessibilityCurrent)
        Text(presentation.weeklyValue)
            .font(.caption)
            .monospacedDigit()
        if let weeklyProgress = presentation.weeklyProgress {
            ProgressView(value: weeklyProgress)
                .tint(provider == .codex ? .blue : .purple)
                .accessibilityLabel(presentation.accessibilityWeekly ?? "Weekly allowance")
        }
        if freshness == .stale {
            Text("Updated \(allowance.fetchedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var providerName: String { provider == .codex ? "Codex" : "Claude" }
}
