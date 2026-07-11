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
    var codexUsageEnabled: Bool {
        didSet { defaults.set(codexUsageEnabled, forKey: "codexUsageEnabled") }
    }
    var claudeUsageEnabled: Bool {
        didSet { defaults.set(claudeUsageEnabled, forKey: "claudeUsageEnabled") }
    }
    var notifyPermission: Bool {
        didSet { defaults.set(notifyPermission, forKey: "notifyPermission") }
    }
    var notifyQuotaLow: Bool {
        didSet { defaults.set(notifyQuotaLow, forKey: "notifyQuotaLow") }
    }
    var serviceStatusEnabled: Bool {
        didSet { defaults.set(serviceStatusEnabled, forKey: "serviceStatusEnabled") }
    }
    private var storedGlassClarity: Double
    var glassClarity: Double {
        get { storedGlassClarity }
        set {
            storedGlassClarity = Self.clampedGlassClarity(newValue)
            defaults.set(storedGlassClarity, forKey: "glassClarity")
        }
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
        self.codexUsageEnabled = defaults.bool(forKey: "codexUsageEnabled")
        self.claudeUsageEnabled = defaults.bool(forKey: "claudeUsageEnabled")
        // Notification toggles default on; absence of a stored value means true.
        self.notifyPermission = defaults.object(forKey: "notifyPermission") as? Bool ?? true
        self.notifyQuotaLow = defaults.object(forKey: "notifyQuotaLow") as? Bool ?? true
        self.serviceStatusEnabled = defaults.bool(forKey: "serviceStatusEnabled")
        self.storedGlassClarity = Self.clampedGlassClarity(
            defaults.object(forKey: "glassClarity") as? Double ?? 0
        )
    }

    private static func clampedGlassClarity(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
