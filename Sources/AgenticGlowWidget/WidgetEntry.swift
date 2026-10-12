import WidgetKit
import AgenticGlowCore

/// `.placeholder` is the generic redacted skeleton WidgetKit shows before
/// any real data has loaded (system-driven, brief). `.result` wraps the
/// actual, honest load outcome from AppGroupSnapshotSource.
enum WidgetPresentationState: Equatable {
    case placeholder
    case result(WidgetSnapshotLoadResult)
}

struct AgenticGlowWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetPresentationState
    /// Which allowance page this entry renders. The timeline carries the
    /// Cursor page now and the overview at its expiry, so the return is
    /// WidgetKit drawing a scheduled entry rather than anything running.
    var page: WidgetAllowancePage = .overview
    /// Where a synchronized snapshot came from and when that Mac observed
    /// it. Nil on the desktop widget, which renders its own Mac's state
    /// and needs no footer; set on the iPhone, where the same views add
    /// the Mac's name and the age of what they show.
    var provenance: WidgetSyncProvenance? = nil
}
