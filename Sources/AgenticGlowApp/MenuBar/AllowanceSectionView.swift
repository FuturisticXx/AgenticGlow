import AgenticGlowCore
import SwiftUI

struct AllowanceSectionView: View {
    @Bindable var model: AppModel
    let usageEnabled: Bool
    /// Mirrors the popover's presentation so a freshly opened popover
    /// always starts collapsed. The hosting controller is reused between
    /// showings, so SwiftUI state would otherwise survive a close.
    var isPopoverPresented: Bool = false
    let enable: () -> Void
    @State private var isAdditionalUsageExpanded = false

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
                let disclosure = AdditionalUsageDisclosure { provider in
                    model.allowanceState(for: provider) != .off
                }
                ForEach(disclosure.primary, id: \.rawValue) { provider in
                    ProviderAllowanceRow(
                        provider: provider,
                        state: model.allowanceState(for: provider)
                    )
                }
                if disclosure.hasAdditionalUsage {
                    additionalUsageToggle
                    if isAdditionalUsageExpanded {
                        ForEach(disclosure.additional, id: \.rawValue) { provider in
                            ProviderAllowanceRow(
                                provider: provider,
                                state: model.allowanceState(for: provider)
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .onChange(of: isPopoverPresented) { _, isPresented in
            if !isPresented { isAdditionalUsageExpanded = false }
        }
    }

    /// Provider-neutral disclosure: no provider name sits beside it, because
    /// more than Cursor may end up behind it. Presentation only, so the tap
    /// triggers no fetch, refresh, or widget reload.
    private var additionalUsageToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isAdditionalUsageExpanded.toggle()
            }
        } label: {
            Image(systemName: AdditionalUsageDisclosure.symbolName(expanded: isAdditionalUsageExpanded))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            AdditionalUsageDisclosure.accessibilityLabel(expanded: isAdditionalUsageExpanded)
        )
        .accessibilityIdentifier("AgenticGlow.AdditionalUsageDisclosure")
    }
}

private struct ProviderAllowanceRow: View {
    let provider: AgentProvider
    let state: AllowanceAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(provider.displayName)
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
        if allowance.pools.isEmpty {
            windowContent(allowance, freshness: freshness)
        } else {
            poolContent(allowance, freshness: freshness)
        }
    }

    /// Pools use the same bar, the same caption styling, and the same
    /// low-allowance treatment as the window rows above, so Cursor sits
    /// beside Codex and Claude as one provider with two allowances
    /// rather than as a second provider card. A shared reset is stated
    /// once under both bars instead of repeated on each.
    @ViewBuilder
    private func poolContent(
        _ allowance: ProviderAllowance,
        freshness: AllowanceFreshness
    ) -> some View {
        let presentation = AllowancePoolPresentation(allowance: allowance, now: Date())
        ForEach(presentation.pools, id: \.id) { pool in
            if let leftPercent = pool.leftPercent {
                AllowanceBar(
                    value: pool.progress,
                    label: leftPercent,
                    tint: tint
                )
                .accessibilityLabel(pool.accessibility)
                allowanceCaption(poolCaption(pool), isLow: pool.isLow)
            } else {
                Text("\(pool.label) · Unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(pool.accessibility)
            }
        }
        if let sharedResetValue = presentation.sharedResetValue {
            Text("Resets \(sharedResetValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        freshnessCaption(allowance, freshness: freshness)
    }

    /// Only when the pools reset at different times does each caption
    /// carry its own reset; otherwise the shared line below says it once.
    private func poolCaption(_ pool: AllowancePoolPresentation.Pool) -> String {
        guard let resetValue = pool.resetValue else { return pool.label }
        return "\(pool.label) · resets \(resetValue)"
    }

    @ViewBuilder
    private func windowContent(
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
        allowanceCaption(presentation.currentDetail, isLow: presentation.currentIsLow)
        if let weeklyProgress = presentation.weeklyProgress {
            AllowanceBar(
                value: weeklyProgress,
                label: presentation.weeklyLeftPercent,
                tint: tint
            )
            .accessibilityLabel(presentation.accessibilityWeekly ?? "Weekly allowance")
            allowanceCaption(weeklyCaption(presentation), isLow: presentation.weeklyIsLow)
        }
        freshnessCaption(allowance, freshness: freshness)
    }

    @ViewBuilder
    private func freshnessCaption(
        _ allowance: ProviderAllowance,
        freshness: AllowanceFreshness
    ) -> some View {
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

    @ViewBuilder
    private func allowanceCaption(_ text: String, isLow: Bool) -> some View {
        if isLow {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .accessibilityHidden(true)
                Text(text)
                    .foregroundStyle(tint)
            }
            .font(.caption.weight(.semibold))
        } else {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var tint: Color {
        ProviderColor.color(for: provider)
    }

    private var providerName: String { provider.displayName }
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
