import SwiftUI

/// Lightweight optical layers that sit above the native system popover glass.
/// The system remains responsible for blur, background sampling, and lensing.
struct LiquidGlassSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let clarity: Double

    var body: some View {
        let appearance = GlassAppearance(
            clarity: clarity,
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )

        ZStack {
            Color.black.opacity(appearance.scrimOpacity)

            LinearGradient(
                colors: [
                    Color.white.opacity(appearance.highlightOpacity),
                    Color.white.opacity(appearance.highlightOpacity * 0.18),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.44)
            )

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(appearance.depthOpacity)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.52),
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(appearance.specularOpacity),
                    .clear
                ],
                center: UnitPoint(x: 0.08, y: 0.02),
                startRadius: 0,
                endRadius: 230
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
