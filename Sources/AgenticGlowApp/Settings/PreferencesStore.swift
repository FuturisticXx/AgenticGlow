import Foundation
import Observation

struct GlobalShortcut: Equatable {
    static let existingDefault = GlobalShortcut(
        keyCode: 0,
        modifiers: 768,
        displayName: "⇧⌘A"
    )

    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String

    /// Command keeps the shortcut deliberate and avoids competing with normal
    /// typing. Command-Q and Command-W retain their universal macOS meanings.
    var isSupported: Bool {
        modifiers & 256 != 0 && ![12, 13].contains(keyCode)
    }
}

enum GlobalShortcutRegistrationResult {
    case registered
    case unavailable
    case invalid
}

/// How the working menu bar icon is colored.
enum MenuBarIconStyle: String, CaseIterable {
    /// Today's behavior: the provider's own color, cross-fading when both
    /// Claude and Codex are working.
    case color
    /// A template icon macOS flattens to the menu bar's own black or
    /// white. Applies to the working icon only; the yellow "needs you",
    /// green celebration, and orange low-allowance badge stay colored,
    /// since those carry meaning rather than provider identity.
    case monochrome
}

@MainActor
@Observable
final class PreferencesStore {
    private var defaults: UserDefaults

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
    var menuBarIconStyle: MenuBarIconStyle {
        didSet { defaults.set(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle") }
    }
    var globalShortcut: GlobalShortcut {
        didSet { persist(globalShortcut) }
    }
    private var storedGlassClarity: Double
    var glassClarity: Double {
        get { storedGlassClarity }
        set {
            storedGlassClarity = Self.clampedGlassClarity(newValue)
            defaults.set(storedGlassClarity, forKey: "glassClarity")
        }
    }

    private var showTimerDidChange: (Bool) -> Void

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
        self.menuBarIconStyle = Self.storedIconStyle(in: defaults)
        self.globalShortcut = Self.storedGlobalShortcut(in: defaults)
        self.storedGlassClarity = Self.clampedGlassClarity(
            defaults.object(forKey: "glassClarity") as? Double ?? 0
        )
        persist(globalShortcut)
    }

    func reconfigure(
        defaults: UserDefaults,
        showTimerDidChange: ((Bool) -> Void)? = nil
    ) {
        let showTimer = defaults.bool(forKey: "showTimer")
        let automaticUpdateChecks = defaults.bool(forKey: "automaticUpdateChecks")
        let diagnosticsEnabled = defaults.bool(forKey: "diagnosticsEnabled")
        let codexUsageEnabled = defaults.bool(forKey: "codexUsageEnabled")
        let claudeUsageEnabled = defaults.bool(forKey: "claudeUsageEnabled")
        let notifyPermission = defaults.object(forKey: "notifyPermission") as? Bool ?? true
        let notifyQuotaLow = defaults.object(forKey: "notifyQuotaLow") as? Bool ?? true
        let serviceStatusEnabled = defaults.bool(forKey: "serviceStatusEnabled")
        let menuBarIconStyle = Self.storedIconStyle(in: defaults)
        let globalShortcut = Self.storedGlobalShortcut(in: defaults)
        let glassClarity = Self.clampedGlassClarity(
            defaults.object(forKey: "glassClarity") as? Double ?? 0
        )

        self.defaults = defaults
        if let showTimerDidChange {
            self.showTimerDidChange = showTimerDidChange
        }
        self.showTimer = showTimer
        self.automaticUpdateChecks = automaticUpdateChecks
        self.diagnosticsEnabled = diagnosticsEnabled
        self.codexUsageEnabled = codexUsageEnabled
        self.claudeUsageEnabled = claudeUsageEnabled
        self.notifyPermission = notifyPermission
        self.notifyQuotaLow = notifyQuotaLow
        self.serviceStatusEnabled = serviceStatusEnabled
        self.menuBarIconStyle = menuBarIconStyle
        self.globalShortcut = globalShortcut
        self.storedGlassClarity = glassClarity
    }

    /// Unknown or absent values fall back to `.color`, which is today's
    /// behavior, so a corrupt or future-written value never leaves the
    /// icon in an unexpected state.
    private static func storedIconStyle(in defaults: UserDefaults) -> MenuBarIconStyle {
        defaults.string(forKey: "menuBarIconStyle")
            .flatMap(MenuBarIconStyle.init(rawValue:)) ?? .color
    }

    private static func storedGlobalShortcut(in defaults: UserDefaults) -> GlobalShortcut {
        guard
            let keyCode = defaults.object(forKey: "globalShortcutKeyCode") as? NSNumber,
            let modifiers = defaults.object(forKey: "globalShortcutModifiers") as? NSNumber,
            let displayName = defaults.string(forKey: "globalShortcutDisplay")
        else {
            return .existingDefault
        }
        let shortcut = GlobalShortcut(
            keyCode: keyCode.uint32Value,
            modifiers: modifiers.uint32Value,
            displayName: displayName
        )
        return shortcut.isSupported ? shortcut : .existingDefault
    }

    private func persist(_ shortcut: GlobalShortcut) {
        defaults.set(shortcut.keyCode, forKey: "globalShortcutKeyCode")
        defaults.set(shortcut.modifiers, forKey: "globalShortcutModifiers")
        defaults.set(shortcut.displayName, forKey: "globalShortcutDisplay")
    }

    private static func clampedGlassClarity(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
