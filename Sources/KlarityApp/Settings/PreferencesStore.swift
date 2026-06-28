import Foundation
import Observation

@MainActor
@Observable
final class PreferencesStore {
    private let defaults: UserDefaults

    var showTimer: Bool {
        didSet { defaults.set(showTimer, forKey: "showTimer") }
    }
    var automaticUpdateChecks: Bool {
        didSet { defaults.set(automaticUpdateChecks, forKey: "automaticUpdateChecks") }
    }
    var diagnosticsEnabled: Bool {
        didSet { defaults.set(diagnosticsEnabled, forKey: "diagnosticsEnabled") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showTimer = defaults.bool(forKey: "showTimer")
        self.automaticUpdateChecks = defaults.bool(forKey: "automaticUpdateChecks")
        self.diagnosticsEnabled = defaults.bool(forKey: "diagnosticsEnabled")
    }
}
