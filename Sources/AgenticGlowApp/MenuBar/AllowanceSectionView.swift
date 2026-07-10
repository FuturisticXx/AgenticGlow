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
                    Text("No usage requests are being made.")
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
        AllowanceBar(
            value: presentation.currentProgress,
            label: presentation.currentLeftPercent,
            tint: tint
        )
        .accessibilityLabel(presentation.accessibilityCurrent)
        Text(presentation.currentDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
        if let weeklyProgress = presentation.weeklyProgress {
            AllowanceBar(
                value: weeklyProgress,
                label: presentation.weeklyLeftPercent,
                tint: tint
            )
            .accessibilityLabel(presentation.accessibilityWeekly ?? "Weekly allowance")
            Text(weeklyCaption(presentation))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if freshness == .stale {
            Text("Updated \(allowance.fetchedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func weeklyCaption(_ presentation: AllowancePresentation) -> String {
        if let reset = presentation.weeklyResetValue {
            return "Week · resets \(reset)"
        }
        return "Week"
    }

    private var tint: Color {
        ProviderColor.color(for: provider)
    }

    private var providerName: String { provider == .codex ? "Codex" : "Claude" }
}

/// Slim capsule allowance bar: quiet track, gradient fill in the provider
/// color, and a floating pill on the fill edge showing the percent left.
private struct AllowanceBar: View {
    let value: Double
    let label: String?
    let tint: Color

    private let pillHalfWidth: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(value, 0), 1)
            let fillWidth = max(4, geo.size.width * clamped)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary).frame(height: 4)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.65), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth, height: 4)
                    .shadow(color: tint.opacity(0.45), radius: 2.5, y: 0.5)
                if let label {
                    Text("\(label)%")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tint))
                        .accessibilityHidden(true)
                        .position(
                            x: min(max(fillWidth, pillHalfWidth), geo.size.width - pillHalfWidth),
                            y: geo.size.height / 2
                        )
                }
            }
        }
        .frame(height: 22)
    }
}
