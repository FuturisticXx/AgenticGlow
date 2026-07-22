import SwiftUI
import AgenticGlowCore

struct AllowanceStrip: View {
    let allowance: WidgetAllowanceSummary
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(WidgetColorPalette.color(for: allowance.provider))
                    .frame(width: 6, height: 6)
                Text(allowance.provider.displayName)
                    .font(.caption2.weight(.bold))
                    .fontWidth(.condensed)
                Spacer()
                Text(WidgetSnapshotFormatting.percentLeftLabel(allowance.currentPercentLeft))
                    .font(.caption2.weight(.bold))
                    .fontWidth(.condensed)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if let percentLeft = allowance.currentPercentLeft {
                // Only rendered when a real value exists: an empty bar for
                // a nil percent would read as "0% left" (out of quota)
                // instead of the true meaning, "we don't know."
                ProgressView(value: percentLeft / 100)
                    .tint(WidgetColorPalette.color(for: allowance.provider))
            }
            if let reset = WidgetSnapshotFormatting.relativeResetLabel(allowance.currentResetAt, now: now) {
                Text("\(allowance.currentWindowLabel) resets in \(reset)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AllowanceStrip(allowance: SampleData.claudeAllowance, now: SampleData.now)
        AllowanceStrip(allowance: SampleData.codexAllowanceLow, now: SampleData.now)
    }
    .padding()
}
