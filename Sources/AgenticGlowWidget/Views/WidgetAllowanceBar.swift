import AppKit
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

    private static let labelPointSize: CGFloat = 12

    /// Built per use rather than held in a `static let`: `NSFont` is not
    /// `Sendable` in every SDK this ships against, and a non-`Sendable`
    /// static is a hard error under Swift 6 language mode. Only the
    /// measured `CGFloat`s are stored.
    private static func labelFont() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: labelPointSize, weight: .semibold)
    }

    /// Every pill is sized for the widest label the bar can show ("100%"),
    /// measured from the real font rather than guessed at. Two reasons:
    /// the clamp in `body` needs the true pill width to keep the pill
    /// inside the canvas (the previous hardcoded 22pt half-width was
    /// narrower than a 3-digit pill, so 100% overhung the widget's right
    /// padding), and a fixed width keeps stacked bars from jittering to
    /// different pill sizes.
    private static let pillWidth: CGFloat = {
        let width = ("100%" as NSString)
            .size(withAttributes: [.font: labelFont()])
            .width
        return width.rounded(.up) + 14
    }()

    private static let pillHeight: CGFloat = {
        let font = labelFont()
        return (font.ascender - font.descender).rounded(.up) + 4
    }()

    private let barHeight: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(progress, 0), 1)
            let fillWidth = max(4, geo.size.width * clamped)
            let pillCenterX = min(
                max(fillWidth, Self.pillWidth / 2),
                geo.size.width - Self.pillWidth / 2
            )
            ZStack(alignment: .leading) {
                bar(width: geo.size.width, fillWidth: fillWidth, pillCenterX: pillCenterX)
                label
                    .position(x: pillCenterX, y: barHeight / 2)
            }
        }
        .frame(height: barHeight)
    }

    @ViewBuilder
    private func bar(width: CGFloat, fillWidth: CGFloat, pillCenterX: CGFloat) -> some View {
        switch renderingMode {
        case .fullColor:
            // The menu bar's own geometry: one continuous track with the
            // fill over it, and an opaque pill sitting on top of both.
            segment(.quaternary, from: 0, to: width)
            segment(
                LinearGradient(
                    colors: [tint.opacity(0.65), tint],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                from: 0,
                to: fillWidth
            )
        default:
            // The Tinted/Monochrome pill is translucent, so a bar running
            // behind it strikes a line straight through the numerals.
            // Erasing that stretch with a destinationOut blend works in a
            // normal render but not in these styles, which composite each
            // element into a material of its own and ignore the blend
            // (verified on a real desktop widget, not in a preview). Leave
            // a real gap in the geometry instead: nothing to erase, so
            // nothing can leak through.
            //
            // The fill also stays a flat primary rather than the provider
            // color, because these styles derive their accent from the
            // wallpaper and a pale wallpaper washes a custom color out.
            let gapStart = max(0, pillCenterX - Self.pillWidth / 2 - 2)
            let gapEnd = min(width, pillCenterX + Self.pillWidth / 2 + 2)
            segment(.quaternary, from: 0, to: gapStart)
            segment(.quaternary, from: gapEnd, to: width)
            segment(Color.primary.opacity(0.55), from: 0, to: min(fillWidth, gapStart))
                .widgetAccentable()
        }
    }

    private func segment(_ style: some ShapeStyle, from: CGFloat, to: CGFloat) -> some View {
        Capsule()
            .fill(style)
            .frame(width: max(0, to - from), height: 4)
            .offset(x: from)
    }

    /// The pill rides the fill edge in every rendering mode, the way the
    /// menu bar's does, rather than degrading to a bare number.
    ///
    /// Full color keeps the menu bar's exact treatment: white numerals on
    /// a solid tinted capsule.
    ///
    /// Tinted/Monochrome can't use that. Those styles map luminance to
    /// prominence, so a solid capsule becomes a translucent wallpaper-
    /// derived material and any text drawn on it lands on the same tone
    /// and disappears. Two earlier attempts failed here: solid text on a
    /// solid pill (washed out), then knocking the numerals out as
    /// transparent holes, which stayed legible but only barely, since the
    /// hole and the pill both resolve from the same wallpaper.
    ///
    /// So these styles carry the contrast on the numerals instead of the
    /// capsule: full-strength text, which renders exactly as legibly as
    /// the provider headings and reset captions around it, over a
    /// low-opacity capsule that supplies the pill shape without competing.
    /// Opacity is the one relationship that survives both the accent
    /// tinting of `.accented` and the luminance mapping of `.vibrant`,
    /// because it is applied after whatever color the system substitutes.
    @ViewBuilder
    private var label: some View {
        switch renderingMode {
        case .fullColor:
            numerals
                .foregroundStyle(.white)
                .frame(width: Self.pillWidth, height: Self.pillHeight)
                .background(Capsule().fill(tint))
                .accessibilityHidden(true)
        default:
            numerals
                .foregroundStyle(.primary)
                .frame(width: Self.pillWidth, height: Self.pillHeight)
                .background(Capsule().fill(Color.primary.opacity(0.25)))
                .widgetAccentable()
                .accessibilityHidden(true)
        }
    }

    private var numerals: some View {
        Text(percentLabel)
            .font(.system(size: Self.labelPointSize, weight: .semibold))
            .monospacedDigit()
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        WidgetAllowanceBar(progress: 1.0, percentLabel: "100%", tint: WidgetColorPalette.codex)
        WidgetAllowanceBar(progress: 0.19, percentLabel: "19%", tint: WidgetColorPalette.codex)
        WidgetAllowanceBar(progress: 0.64, percentLabel: "64%", tint: WidgetColorPalette.claude)
        WidgetAllowanceBar(progress: 0.53, percentLabel: "53%", tint: WidgetColorPalette.claude)
        WidgetAllowanceBar(progress: 0.0, percentLabel: "0%", tint: WidgetColorPalette.claude)
    }
    .padding()
}
