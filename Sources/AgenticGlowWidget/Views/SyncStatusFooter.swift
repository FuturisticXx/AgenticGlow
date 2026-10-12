import SwiftUI
import WidgetKit
import AgenticGlowCore

/// The one line a synchronized widget adds under the desktop layout: the
/// Mac's name and how old what it shows is. Same 11pt secondary caption
/// as the reset lines, so it reads as part of the widget rather than as
/// a status bar; only the offline case borrows the low-allowance amber
/// weight of the text, without an icon, since it reports rather than
/// alarms.
struct SyncStatusFooter: View {
    let provenance: WidgetSyncProvenance
    let now: Date
    /// Small drops the Mac's name; the canvas has no room for it.
    var compact = false

    var body: some View {
        let freshness = provenance.freshness(now: now)
        HStack(spacing: 4) {
            Image(systemName: freshness.isFresh ? "macbook" : "macbook.slash")
                .accessibilityHidden(true)
            Text(compact ? provenance.compactFooter(now: now) : provenance.footer(now: now))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(provenance.footer(now: now))
    }
}
