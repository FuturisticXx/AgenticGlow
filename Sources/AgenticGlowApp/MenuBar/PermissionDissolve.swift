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

    private static func eased(_ linear: Double) -> Double {
        (1 - cos(.pi * linear)) / 2
    }
}
