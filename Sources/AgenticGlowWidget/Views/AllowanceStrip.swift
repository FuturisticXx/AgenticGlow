import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Renders every available allowance window for one provider (current,
/// and weekly when the provider reports one) using the menu-bar-style
/// status bar. Data-driven: a provider with only a current window shows
/// one bar, a provider with both shows two, matching `allowance.windows`.
struct AllowanceStrip: View {
    let allowance: WidgetAllowanceSummary
    let now: Date

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(renderingMode == .fullColor ? WidgetColorPalette.color(for: allowance.provider) : Color.primary)
                    .frame(width: 6, height: 6)
                    .widgetAccentable()
                Text(allowance.provider.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            ForEach(allowance.windows) { window in
                AllowanceWindowRow(window: window, captionLabel: window.label, now: now)
            }
        }
    }
}

/// One allowance window: a status bar (or an "Unavailable" line when the
/// value is unknown) plus a caption. Reused standalone by the medium and
/// small widgets to show a single lowest window with its provider spelled
/// out in the caption (e.g. "Codex · Weekly"), and by `AllowanceStrip`
/// under a shared provider heading (caption just "Weekly").
struct AllowanceWindowRow: View {
    let window: WidgetAllowanceWindow
    let captionLabel: String
    let now: Date

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let percentLeft = window.percentLeft, let progress = window.normalizedProgress {
                // Only rendered when a real value exists: an empty bar for
                // a nil percent would read as "0% left" (out of quota)
                // instead of the true meaning, "we don't know."
                WidgetAllowanceBar(
                    progress: progress,
                    percentLabel: "\(Int(percentLeft.rounded()))%",
                    tint: WidgetColorPalette.color(for: window.provider)
                )
                caption(percentLeft: percentLeft)
            } else {
                Text("\(captionLabel) · Unavailable")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func caption(percentLeft: Double) -> some View {
        let resetText = WidgetSnapshotFormatting.relativeResetLabel(window.resetAt, now: now)
        let text = resetText.map { "\(captionLabel) resets in \($0)" } ?? captionLabel
        if isLow {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(red: 1, green: 0.23, blue: 0.19))
                    .accessibilityHidden(true)
                Text(text)
                    .foregroundStyle(renderingMode == .fullColor ? WidgetColorPalette.color(for: window.provider) : Color.primary)
            }
            .font(.system(size: 11, weight: .medium))
        } else {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var isLow: Bool {
        guard let percentLeft = window.percentLeft else { return false }
        return percentLeft < AllowanceWarning.thresholdPercentLeft
    }

    private var accessibilityLabel: String {
        var parts = [window.provider.displayName, window.label]
        if let percentLeft = window.percentLeft {
            parts.append("\(Int(percentLeft.rounded())) percent left")
            if let reset = WidgetSnapshotFormatting.relativeResetLabel(window.resetAt, now: now) {
                parts.append("resets in \(reset)")
            }
            if isLow {
                parts.append("low")
            }
        } else {
            parts.append("unavailable")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AllowanceStrip(allowance: SampleData.claudeAllowance, now: SampleData.now)
        AllowanceStrip(allowance: SampleData.codexAllowanceLow, now: SampleData.now)
    }
    .padding()
}
