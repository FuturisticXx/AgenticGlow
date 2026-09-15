import Foundation

/// Timeline for the combined permission + working icon: the hexagon holds,
/// dissolves into the yellow exclamation, holds, and dissolves back, on an
/// 11-second cycle. Pure math so the shape is unit-testable without AppKit.
enum PermissionDissolve {
    static let workingDwell: Double = 6
    static let fade: Double = 1
    static let permissionDwell: Double = 3
    static var cycle: Double { workingDwell + fade + permissionDwell + fade }

    /// Opacity of the working hexagon at `seconds` on the motion clock; the
    /// exclamation draws at the complement. Fades use a cosine ease so
    /// neither end of the dissolve snaps.
    static func workingOpacity(at seconds: Double) -> Double {
        let t = seconds.truncatingRemainder(dividingBy: cycle)
        if t < workingDwell { return 1 }
        if t < workingDwell + fade {
            return eased(1 - (t - workingDwell) / fade)
        }
        if t < workingDwell + fade + permissionDwell { return 0 }
        return eased((t - workingDwell - fade - permissionDwell) / fade)
    }

    /// Blue share of the two-provider color sweep while dissolving. The free
    /// running 10-second sweep drifts against the 11-second dissolve, which
    /// parked the orange peak inside the yellow dwell where nobody sees it.
    /// Synced instead: each working dwell plays one full sweep, blue at both
    /// fades and peak orange at the dwell's center, so every cycle shows the
    /// whole color story.
    static func sweepBlueShare(at seconds: Double) -> Double {
        let t = seconds.truncatingRemainder(dividingBy: cycle)
        guard t < workingDwell else { return 1 }
        return (1 + cos(2 * .pi * t / workingDwell)) / 2
    }

    private static func eased(_ linear: Double) -> Double {
        (1 - cos(.pi * linear)) / 2
    }
}
