import AppKit
import SwiftUI
import KlarityCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItemController: StatusItemController!
    private var reduceMotionObserver: ReduceMotionObserver!
    private var setupWindow: NSWindow?
    private var uiTestSessionWindow: NSWindow?
    private var preferences = PreferencesStore()
    private var updateViewModel = UpdateViewModel()
    private let launchAtLogin = LaunchAtLoginService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Support noninteractive clean-removal mode
        if CommandLine.arguments.contains("--remove-integrations") {
            performCleanRemoval()
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Check for UI test fixtures
        let store: SessionStateStoring
        if let fixtureEvents = UITestFixtureFactory.events(arguments: CommandLine.arguments) {
            store = UITestSessionStore(events: fixtureEvents)
        } else {
            store = FileSessionStateStore(directory: FileSessionStateStore.defaultDirectory)
        }

        model = AppModel(
            store: store,
            processMonitor: DarwinProcessMonitor(),
            activator: SourceApplicationActivator()
        )
        statusItemController = StatusItemController(
            model: model,
            openIntegrations: { [weak self] in self?.showSetupWindow() }
        )
        reduceMotionObserver = ReduceMotionObserver(
            model: model,
            notificationCenter: NSWorkspace.shared.notificationCenter,
            reduceMotionEnabled: {
                NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        )
        reduceMotionObserver.start()
        model.start()

        let fixtureName = UITestFixtureFactory.name(arguments: CommandLine.arguments)
        if fixtureName != nil {
            let suiteName = "\(ProductMetadata.bundleIdentifier).ui-tests.\(ProcessInfo.processInfo.processIdentifier)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            configurePreferences(defaults: defaults)
        } else {
            let defaults = UserDefaults.standard
            configurePreferences(defaults: defaults)
            Task {
                await updateViewModel.check(
                    manual: false,
                    automaticEnabled: preferences.automaticUpdateChecks
                )
            }
        }

        if fixtureName == "setup-repair" {
            showSetupWindow()
        } else if fixtureName == nil,
                  !UserDefaults.standard.bool(forKey: "completedSetup") {
            showSetupWindow()
        }
        if fixtureName != nil,
           CommandLine.arguments.contains("--ui-test-open-popover") {
            DispatchQueue.main.async { [weak self] in
                self?.showUITestSessionWindow()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        statusItemController.stop()
        reduceMotionObserver.stop()
    }

    func makeSettingsView() -> some View {
        SettingsView(
            preferences: preferences,
            updates: updateViewModel,
            launchAtLogin: launchAtLogin,
            openIntegrations: { [weak self] in self?.showSetupWindow() }
        )
    }

    private func showSetupWindow() {
        if let setupWindow {
            setupWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Klarity Setup"
        window.center()
        window.contentViewController = NSHostingController(rootView: makeSetupView {
            if UITestFixtureFactory.name(arguments: CommandLine.arguments) == nil {
                UserDefaults.standard.set(true, forKey: "completedSetup")
            }
            self.setupWindow?.close()
            self.setupWindow = nil
        })
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupWindow = window
    }

    private func showUITestSessionWindow() {
        if let uiTestSessionWindow {
            uiTestSessionWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Klarity"
        window.center()
        window.contentViewController = NSHostingController(
            rootView: SessionListView(
                model: model,
                openIntegrations: { [weak self] in self?.showSetupWindow() }
            )
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        uiTestSessionWindow = window
    }

    private func makeSetupView(onComplete: @escaping () -> Void) -> some View {
        if let models = UITestFixtureFactory.setupRepairModels(
            arguments: CommandLine.arguments
        ) {
            return SetupView(
                claude: models.claude,
                codex: models.codex,
                onComplete: onComplete
            )
        }

        let helperSource = Bundle.main.url(
            forResource: "klarity-event",
            withExtension: nil,
            subdirectory: "bin"
        ) ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/klarity-event")

        let helperInstaller = HelperInstaller(
            sourceURL: helperSource,
            destinationURL: HelperInstaller.defaultDestination
        )

        let claudeSettingsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        let codexHooksURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/hooks.json")

        let claudeManager = ClaudeIntegrationManager(
            settingsURL: claudeSettingsURL,
            helperURL: HelperInstaller.defaultDestination
        )
        let codexManager = CodexIntegrationManager(
            hooksURL: codexHooksURL,
            helperURL: HelperInstaller.defaultDestination
        )

        let store = FileSessionStateStore(directory: FileSessionStateStore.defaultDirectory)
        let syntheticEventService = SyntheticEventService(store: store)

        let claudeExecutable = ExecutableLocator.locate("claude")
        let codexExecutable = ExecutableLocator.locate("codex")

        let claudeModel = SetupViewModel(
            provider: .claude,
            executableURL: claudeExecutable,
            helperInstaller: helperInstaller,
            integration: claudeManager,
            syntheticEventService: syntheticEventService,
            lastEvent: { [weak model] in
                model?.resolved.sessions
                    .first { $0.provider == .claude }?.updatedAt
            }
        )

        let codexModel = SetupViewModel(
            provider: .codex,
            executableURL: codexExecutable,
            helperInstaller: helperInstaller,
            integration: codexManager,
            syntheticEventService: syntheticEventService,
            lastEvent: { [weak model] in
                model?.resolved.sessions
                    .first { $0.provider == .codex }?.updatedAt
            }
        )

        return SetupView(
            claude: claudeModel,
            codex: codexModel,
            onComplete: onComplete
        )
    }

    private func performCleanRemoval() {
        let claudeSettingsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        let codexHooksURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/hooks.json")
        let helperDestination = HelperInstaller.defaultDestination

        try? ClaudeIntegrationManager(
            settingsURL: claudeSettingsURL,
            helperURL: helperDestination
        ).remove()
        try? CodexIntegrationManager(
            hooksURL: codexHooksURL,
            helperURL: helperDestination
        ).remove()
        try? FileManager.default.removeItem(at: helperDestination)
    }

    private func configurePreferences(defaults: UserDefaults) {
        preferences = PreferencesStore(
            defaults: defaults,
            showTimerDidChange: { [weak self] showTimer in
                self?.model.showTimer = showTimer
            }
        )
        model.showTimer = preferences.showTimer
        updateViewModel = UpdateViewModel(defaults: defaults)
    }
}

@MainActor
final class ReduceMotionObserver: NSObject {
    private let model: AppModel
    private let notificationCenter: NotificationCenter
    private let reduceMotionEnabled: () -> Bool

    init(
        model: AppModel,
        notificationCenter: NotificationCenter,
        reduceMotionEnabled: @escaping () -> Bool
    ) {
        self.model = model
        self.notificationCenter = notificationCenter
        self.reduceMotionEnabled = reduceMotionEnabled
    }

    func start() {
        updateReduceMotion()
        notificationCenter.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    func stop() {
        notificationCenter.removeObserver(
            self,
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    @objc private func accessibilityDisplayOptionsDidChange() {
        updateReduceMotion()
    }

    private func updateReduceMotion() {
        model.reduceMotion = reduceMotionEnabled()
    }
}
