import SwiftUI
import WidgetKit

/// Widget-local port of the menu bar's slim capsule allowance bar (see
/// `AllowanceSectionView.swift`, frozen — reference only): quiet track,
/// gradient fill in the provider color, and a floating pill on the fill
/// edge showing the percent left. Duplicated here rather than imported
/// because the widget extension must not depend on the AppKit-flavored
/// AgenticGlowApp target.
struct WidgetAllowanceBar: View {
    /// Already-normalized 0...1 progress (see `WidgetAllowanceWindow.normalizedProgress`).
    let progress: Double
    let percentLabel: String
    let tint: Color

    @Environment(\.widgetRenderingMode) private var renderingMode

    private let pillHalfWidth: CGFloat = 22
    private let barHeight: CGFloat = 22
    private let labelTrailingOffset: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(progress, 0), 1)
            let fillWidth = max(4, geo.size.width * clamped)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary).frame(height: 4)
                fill(width: fillWidth)
                label(fillWidth: fillWidth, totalWidth: geo.size.width)
            }
        }
        .frame(height: barHeight)
    }

    @ViewBuilder
    private func fill(width: CGFloat) -> some View {
        switch renderingMode {
        case .fullColor:
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.65), tint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 4)
        default:
            // Tinted/Monochrome desktop widget styles derive their accent
            // from the current wallpaper; a pale wallpaper pushes that
            // accent close to white, which made the provider color here
            // (and any text sitting on it) unreadable in practice even
            // after marking it .widgetAccentable(). Fall back to a
            // guaranteed-legible primary fill instead of fighting a
            // system color substitution this view can't predict.
            Capsule()
                .fill(Color.primary.opacity(0.55))
                .frame(width: width, height: 4)
                .widgetAccentable()
        }
    }

    @ViewBuilder
    private func label(fillWidth: CGFloat, totalWidth: CGFloat) -> some View {
        Group {
            switch renderingMode {
            case .fullColor:
                Text(percentLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(tint).widgetAccentable())
            default:
                // No colored pill outside full-color mode: .primary text
                // is the one style WidgetKit guarantees stays legible
                // against whatever it substitutes for tinted/monochrome
                // rendering, unlike a background+foreground color pairing
                // this view can't verify against every wallpaper.
                Text(percentLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityHidden(true)
        .position(
            // Offset past the fill edge rather than straddling it evenly:
            // centering the label exactly on the edge reads as floating
            // in the middle of nowhere once it's plain text with no pill
            // background anchoring it to the fill (John: "shift... to the
            // right some").
            x: min(max(fillWidth + labelTrailingOffset, pillHalfWidth), totalWidth - pillHalfWidth),
            y: barHeight / 2
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        WidgetAllowanceBar(progress: 0.19, percentLabel: "19%", tint: WidgetColorPalette.codex)
        WidgetAllowanceBar(progress: 0.64, percentLabel: "64%", tint: WidgetColorPalette.claude)
        WidgetAllowanceBar(progress: 0.53, percentLabel: "53%", tint: WidgetColorPalette.claude)
    }
    .padding()
}
