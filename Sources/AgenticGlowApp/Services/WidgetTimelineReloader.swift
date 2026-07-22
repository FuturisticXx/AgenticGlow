import WidgetKit

protocol WidgetTimelineReloading: Sendable {
    func reloadAll()
}

struct SystemWidgetTimelineReloader: WidgetTimelineReloading {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
