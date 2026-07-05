import AppKit
import Network
import SwiftUI
import AgenticGlowCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItemController: StatusItemController!
    private var reduceMotionObserver: ReduceMotionObserver!
    private var usageAvailabilityObserver: UsageAvailabilityObserver!
    private var setupWindow: NSWindow?
    private var uiTestSessionWindow: NSWindow?
    private var preferences = PreferencesStore()
    private var updateViewModel = UpdateViewModel()
    private let launchAtLogin = LaunchAtLoginService()
    private var claudeCredentialStore: any ClaudeSessionCredentialStoring =
        ClaudeSessionCredentialStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Support noninteractive clean-removal mode
        if CommandLine.arguments.contains("--remove-integrations") {
            performCleanRemoval()
            exit(EXIT_SUCCESS)
        }

        NSApp.setActivationPolicy(.accessory)
        let fixtureName = UITestFixtureFactory.name(arguments: CommandLine.arguments)
        if fixtureName != nil {
            claudeCredentialStore = InMemoryClaudeSessionCredentialStore()
        }

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
            activator: SourceApplicationActivator(),
            allowanceCoordinator: makeAllowanceCoordinator(isUITest: fixtureName != nil)
        )

        if fixtureName != nil {
            let suiteName = "\(ProductMetadata.bundleIdentifier).ui-tests.\(ProcessInfo.processInfo.processIdentifier)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            if fixtureName == "allowance-unavailable" {
                defaults.set(true, forKey: "codexUsageEnabled")
            }
            configurePreferences(defaults: defaults)
        } else {
            configurePreferences(defaults: .standard)
        }

        statusItemController = StatusItemController(
            model: model,
            preferences: preferences,
            claudeCredentialStore: claudeCredentialStore,
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
        usageAvailabilityObserver = UsageAvailabilityObserver(model: model)
        usageAvailabilityObserver.start()
        model.start()
        Task {
            await model.setUsageEnabled(preferences.codexUsageEnabled, provider: .codex)
            await model.setUsageEnabled(preferences.claudeUsageEnabled, provider: .claude)
        }

        if fixtureName == nil {
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
        usageAvailabilityObserver.stop()
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
        window.title = "AgenticGlow Setup"
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AgenticGlow"
        window.center()
        window.contentViewController = NSHostingController(
            rootView: SessionListView(
                model: model,
                preferences: preferences,
                claudeCredentialStore: claudeCredentialStore,
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
            forResource: "agenticglow-event",
            withExtension: nil,
            subdirectory: "bin"
        ) ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/agenticglow-event")

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

    private func makeAllowanceCoordinator(isUITest: Bool) -> AllowanceRefreshCoordinator {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = base
            .appendingPathComponent(ProductMetadata.displayName, isDirectory: true)
            .appendingPathComponent("Allowance", isDirectory: true)
        let codexAdapter: any AllowanceProviding
        if isUITest {
            codexAdapter = UnavailableAllowanceAdapter(
                provider: .codex,
                reason: "Disabled in UI tests."
            )
        } else if let executable = ExecutableLocator.locate("codex") {
            codexAdapter = CodexAllowanceAdapter(
                requester: CodexAppServerClient(executableURL: executable)
            )
        } else {
            codexAdapter = UnavailableAllowanceAdapter(
                provider: .codex,
                reason: "Sign in to the Codex app or CLI first."
            )
        }
        let claudeCredentialStore = self.claudeCredentialStore
        let claudeAdapter = ClaudeAllowanceAdapter(
            sessionCookie: { try claudeCredentialStore.load() ?? "" }
        )
        return AllowanceRefreshCoordinator(
            adapters: [codexAdapter, claudeAdapter],
            cache: FileAllowanceCache(directory: directory)
        )
    }
}

@MainActor
final class UsageAvailabilityObserver: NSObject {
    private let model: AppModel
    private let monitor = NWPathMonitor()
    private let notificationCenter = NSWorkspace.shared.notificationCenter
    private var asleep = false
    private var networkAvailable = true

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        notificationCenter.addObserver(
            self,
            selector: #selector(willSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.networkAvailable = path.status == .satisfied
                self?.apply()
            }
        }
        monitor.start(queue: DispatchQueue(label: "AgenticGlow.NetworkPath"))
    }

    func stop() {
        monitor.cancel()
        notificationCenter.removeObserver(self)
    }

    @objc private func willSleep() {
        asleep = true
        apply()
    }

    @objc private func didWake() {
        asleep = false
        apply()
    }

    private func apply() {
        let suspended = asleep || !networkAvailable
        Task { await model.setUsageSuspended(suspended) }
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
