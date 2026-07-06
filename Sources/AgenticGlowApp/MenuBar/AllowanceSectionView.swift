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
                .frame(maxWidth: .infinity, alignment: .center)
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
        currentValueText(presentation)
            .font(.callout.weight(.medium))
            .monospacedDigit()
        Text(presentation.currentDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
        AllowanceBar(value: presentation.currentProgress, tint: tint)
            .accessibilityLabel(presentation.accessibilityCurrent)
        weeklyValueText(presentation)
            .font(.caption)
            .monospacedDigit()
        if let weeklyProgress = presentation.weeklyProgress {
            AllowanceBar(value: weeklyProgress, tint: tint)
                .accessibilityLabel(presentation.accessibilityWeekly ?? "Weekly allowance")
        }
        if freshness == .stale {
            Text("Updated \(allowance.fetchedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func currentValueText(_ presentation: AllowancePresentation) -> Text {
        guard let left = presentation.currentLeftPercent else {
            return Text(presentation.currentValue)
        }
        var text = Text("\(left)% left")
        if provider == .claude, let used = presentation.currentUsedPercent {
            text = text + Text(" · \(used)% used")
        }
        return text
    }

    private func weeklyValueText(_ presentation: AllowancePresentation) -> Text {
        guard let left = presentation.weeklyLeftPercent else {
            return Text(presentation.weeklyValue)
        }
        var text = Text("Week \(left)%")
        if provider == .claude, let used = presentation.weeklyUsedPercent {
            text = text + Text(" · \(used)% used")
        }
        if let reset = presentation.weeklyResetValue {
            text = text + Text(" · \(reset)")
        }
        return text
    }

    private var tint: Color {
        provider == .codex
            ? Color(red: 0.25, green: 0.55, blue: 1.00)
            : Color(red: 0.85, green: 0.47, blue: 0.34)
    }

    private var providerName: String { provider == .codex ? "Codex" : "Claude" }
}

/// Slim capsule allowance bar: quiet track, gradient fill in the provider
/// color, and a faint glow so it reads as lit rather than painted.
private struct AllowanceBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.65), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, geo.size.width * min(max(value, 0), 1)))
                    .shadow(color: tint.opacity(0.45), radius: 2.5, y: 0.5)
            }
        }
        .frame(height: 4)
    }
}
