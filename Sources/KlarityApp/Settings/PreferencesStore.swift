import Foundation
import Observation

@MainActor
@Observable
final class PreferencesStore {
    private let defaults: UserDefaults

    var showTimer: Bool {
        didSet {
            defaults.set(showTimer, forKey: "showTimer")
            showTimerDidChange(showTimer)
        }
    }
    var automaticUpdateChecks: Bool {
        didSet { defaults.set(automaticUpdateChecks, forKey: "automaticUpdateChecks") }
    }
    var diagnosticsEnabled: Bool {
        didSet { defaults.set(diagnosticsEnabled, forKey: "diagnosticsEnabled") }
    }

    private let showTimerDidChange: (Bool) -> Void

    init(
        defaults: UserDefaults = .standard,
        showTimerDidChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.defaults = defaults
        self.showTimerDidChange = showTimerDidChange
        self.showTimer = defaults.bool(forKey: "showTimer")
        self.automaticUpdateChecks = defaults.bool(forKey: "automaticUpdateChecks")
        self.diagnosticsEnabled = defaults.bool(forKey: "diagnosticsEnabled")
    }
}
