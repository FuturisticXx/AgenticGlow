import SwiftUI
import WidgetKit
import AgenticGlowCore

/// Renders every available allowance window for one provider (current,
/// and weekly when the provider reports one) using the menu-bar-style
/// status bar. Data-driven: a provider with only a current window shows
/// one bar, a provider with both shows two, matching `allowance.windows`.
struct AllowanceStrip: View {
    let allowance: WidgetAllowanceSummary
    /// Cleared when the canvas is carrying so many windows that reset
    /// captions would push a bar off the bottom. Percentages and the low
    /// warning survive; the reset detail is what yields.
    var showsResets = true
    /// Cleared on the Cursor page, whose own heading already names the
    /// provider; repeating it would spend a line saying it twice.
    var showsProviderHeading = true
    let now: Date

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsProviderHeading {
                providerHeading
            }
            ForEach(allowance.windows) { window in
                AllowanceWindowRow(
                    window: window,
                    captionLabel: window.label,
                    showsReset: showsResets && sharedPoolReset == nil,
                    now: now
                )
            }
            if showsResets, let sharedPoolReset {
                Text("Resets \(sharedPoolReset)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var providerHeading: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(renderingMode == .fullColor ? WidgetColorPalette.color(for: allowance.provider) : Color.primary)
                .frame(width: 6, height: 6)
                .widgetAccentable()
            Text(allowance.provider.displayName)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    /// Formatted form of `WidgetAllowanceSummary.sharedPoolResetAt`,
    /// matching the reset copy the per-window captions use.
    private var sharedPoolReset: String? {
        guard let first = allowance.sharedPoolResetAt else { return nil }
        return WidgetSnapshotFormatting.captionResetDetail(first, now: now)
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
    /// Cleared when a provider states one shared reset beneath its rows.
    var showsReset = true
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
        let text = (showsReset ? resetDetail : nil)
            .map { "\(captionLabel) resets \($0)" } ?? captionLabel
        if isLow {
            // The icon takes width the caption used to have, which is how
            // a long next-day reset came to truncate. It is pinned to its
            // intrinsic size and the caption is given the priority, so
            // the remaining width all goes to the text.
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(red: 1, green: 0.23, blue: 0.19))
                    .accessibilityHidden(true)
                    .layoutPriority(0)
                captionText(text)
                    .foregroundStyle(renderingMode == .fullColor ? WidgetColorPalette.color(for: window.provider) : Color.primary)
                    .layoutPriority(1)
            }
            .font(.system(size: 11, weight: .medium))
        } else {
            captionText(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    /// One line, and a small amount of give before it would ever clip.
    /// Scoped to this caption rather than the widget's typography.
    private func captionText(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isLow: Bool {
        guard let percentLeft = window.percentLeft else { return false }
        return percentLeft < AllowanceWarning.thresholdPercentLeft
    }

    /// Matches the menu bar's own reset copy (`AllowancePresentation`): a
    /// countdown pairs with the absolute clock time (plus date if it isn't
    /// today) in parentheses, but only while the reset is close enough for
    /// the countdown to help. `WidgetSnapshotFormatting.showsCountdown`
    /// owns that rule for both surfaces.
    ///
    /// Keyed off the reset's distance rather than `window.kind`, because
    /// kind alone gets it wrong: Codex reports its weekly-scale window as
    /// `.current`, which is how this line read "Weekly resets in 166h 12m
    /// left (Sat, Aug 1 at 2:31 AM)".
    private var resetDetail: String? {
        guard let resetAt = window.resetAt else { return nil }
        return WidgetSnapshotFormatting.captionResetDetail(resetAt, now: now)
    }

    private var accessibilityLabel: String {
        var parts = [window.provider.displayName, window.label]
        if let percentLeft = window.percentLeft {
            parts.append("\(Int(percentLeft.rounded())) percent left")
            if let resetDetail {
                parts.append("resets \(resetDetail)")
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
