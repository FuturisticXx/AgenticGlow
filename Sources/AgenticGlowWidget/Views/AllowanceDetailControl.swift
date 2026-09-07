import SwiftUI
import WidgetKit
import AgenticGlowCore

/// The affordance for the temporary allowance detail page: one small
/// chevron at the trailing edge, below the bars.
///
/// Deliberately unnamed. It says "there is more allowance detail here",
/// not "there is Cursor here", so the default widget's chrome stays
/// uncoupled from whichever provider happens to have a detail page. It
/// routes straight to Cursor today, which is the only provider with
/// pools; that is a routing detail rather than something the control
/// should announce.
///
/// The glyph is small on purpose, so the hit target is padded well past
/// it. The accessibility label carries the meaning the shape cannot.
struct AllowanceDetailControl: View {
    var body: some View {
        Button(intent: ShowCursorUsageIntent()) {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                // Generous around a small glyph: the padding is the hit
                // target, and it also holds the chevron clear of the
                // card's rounded corner.
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show more allowance details")
    }
}
