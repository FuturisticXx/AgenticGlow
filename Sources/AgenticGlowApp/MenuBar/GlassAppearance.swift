import SwiftUI

/// Static material-layer values that complement the system Liquid Glass
/// popover without replacing its native blur, lensing, or adaptivity.
struct GlassAppearance: Equatable {
    let clarity: Double
    let scrimOpacity: Double
    let highlightOpacity: Double
    let depthOpacity: Double
    let specularOpacity: Double

    init(
        clarity requestedClarity: Double,
        colorScheme: ColorScheme,
        reduceTransparency: Bool
    ) {
        let requested = min(max(requestedClarity, 0), 1)
        let clarity = reduceTransparency ? 0 : requested
        self.clarity = clarity

        switch colorScheme {
        case .dark:
            scrimOpacity = Self.interpolate(from: 0.45, to: 0, progress: clarity)
            highlightOpacity = 0.06 * clarity
            depthOpacity = 0.03 * clarity
            specularOpacity = 0.09 * clarity
        case .light:
            scrimOpacity = 0
            highlightOpacity = 0.08 * clarity
            depthOpacity = 0.02 * clarity
            specularOpacity = 0.12 * clarity
        @unknown default:
            scrimOpacity = 0
            highlightOpacity = 0.07 * clarity
            depthOpacity = 0.025 * clarity
            specularOpacity = 0.10 * clarity
        }
    }

    private static func interpolate(from: Double, to: Double, progress: Double) -> Double {
        from + ((to - from) * progress)
    }
}
