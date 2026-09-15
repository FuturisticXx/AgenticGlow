import SwiftUI
import WidgetKit
import AgenticGlowCore

/// The temporary Cursor allowance page. Replaces the overview rather than
/// stacking under it, so the canvas carries two bars instead of six.
///
/// Deliberately built from the same pieces as the overview: the same bar,
/// the same caption styling, the same low-allowance treatment, the same
/// shared-reset rule. Only the heading and the return control are new.
struct CursorDetailView: View {
    let allowance: WidgetAllowanceSummary
    let now: Date
    /// Small canvases show the pools without a heading row; there is no
    /// room for one and the page is unambiguous without it.
    var showsHeader = true

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsHeader {
                header
            }
            AllowanceStrip(allowance: allowance, showsProviderHeading: false, now: now)
        }
    }

    private var header: some View {
        Button(intent: ReturnToAllowanceOverviewIntent()) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Circle()
                    .fill(
                        renderingMode == .fullColor
                            ? WidgetColorPalette.color(for: allowance.provider)
                            : Color.primary
                    )
                    .frame(width: 6, height: 6)
                    .widgetAccentable()
                Text("\(allowance.provider.displayName) Usage")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Return to allowance overview")
    }
}
