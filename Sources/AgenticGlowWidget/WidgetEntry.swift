import WidgetKit
import AgenticGlowCore

/// `.placeholder` is the generic redacted skeleton WidgetKit shows before
/// any real data has loaded (system-driven, brief). `.result` wraps the
/// actual, honest load outcome from AppGroupSnapshotSource.
enum WidgetPresentationState {
    case placeholder
    case result(WidgetSnapshotLoadResult)
}

struct AgenticGlowWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetPresentationState
}
