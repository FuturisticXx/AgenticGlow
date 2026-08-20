import AppKit
import Carbon
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
    private var notificationService: AgentNotificationService?
    private var usageResetCoordinator: UsageResetAlertCoordinator?
    private var messagesRecipientStore: any MessagesRecipientStoring = MessagesRecipientStore()
    private let notificationClient = UserNotificationCenterClient()
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandlerRef: EventHandlerRef?
    private static let hotKeyID = EventHotKeyID(signature: OSType(0x41474C57), id: 1) // "AGLW"

    @discardableResult
    private func registerGlobalHotKey(_ shortcut: GlobalShortcut) -> GlobalShortcutRegistrationResult {
        guard shortcut.isSupported else { return .invalid }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        if hotKeyEventHandlerRef == nil {
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, userData in
                    guard let userData else { return noErr }
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                    delegate.handleGlobalHotKeyPressed()
                    return noErr
                },
                1,
                &eventType,
                selfPtr,
                &hotKeyEventHandlerRef
            )
        }
        var newHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )
        guard status == noErr, let newHotKeyRef else {
            return .unavailable
        }
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = newHotKeyRef
        return .registered
    }

    private func unregisterGlobalHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let hotKeyEventHandlerRef {
            RemoveEventHandler(hotKeyEventHandlerRef)
            self.hotKeyEventHandlerRef = nil
        }
    }

    private func handleGlobalHotKeyPressed() {
        statusItemController.togglePopover()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Support noninteractive clean-removal mode
        if CommandLine.arguments.contains("--remove-integrations") {
            performCleanRemoval()
            exit(EXIT_SUCCESS)
        }

        // AgenticGlow's Setup and Settings windows are transient utility
        // panels, not documents — they must never be restored by macOS's
        // "reopen windows" feature. This only became observable once the
        // repair-restart flow existed: relaunching the app for the first
        // time surfaced the Settings window reappearing unbidden alongside
        // the intentionally-reopened Setup window.
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])

        NSApp.setActivationPolicy(.accessory)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        let visualQA = VisualQALaunchConfiguration(arguments: CommandLine.arguments)
        if let visualQA {
            NSApp.appearance = NSAppearance(
                named: visualQA.appearance == .dark ? .darkAqua : .aqua
            )
        }
        let fixtureName = visualQA == nil
            ? UITestFixtureFactory.name(arguments: CommandLine.arguments)
            : "empty"
        if fixtureName != nil {
            claudeCredentialStore = InMemoryClaudeSessionCredentialStore()
            messagesRecipientStore = InMemoryMessagesRecipientStore()
        }

        // Check for UI test fixtures
        let store: SessionStateStoring
        if visualQA != nil {
            store = FileSessionStateStore(directory: FileSessionStateStore.defaultDirectory)
        } else if let fixtureEvents = UITestFixtureFactory.events(arguments: CommandLine.arguments) {
            store = UITestSessionStore(events: fixtureEvents)
        } else {
            store = FileSessionStateStore(directory: FileSessionStateStore.defaultDirectory)
        }

        let activator = SourceApplicationActivator()
        if fixtureName == nil || fixtureName == "signals" {
            notificationClient.activate()
            notificationService = AgentNotificationService(
                scheduler: notificationClient,
                permissionEnabled: { [weak self] in self?.preferences.notifyPermission ?? false },
                quotaEnabled: { [weak self] in self?.preferences.notifyQuotaLow ?? false },
                activate: { activator.activate(bundleIdentifier: $0) }
            )
            usageResetCoordinator = UsageResetAlertCoordinator(
                scheduler: notificationClient,
                messages: MessagesNotifier(),
                recipientStore: messagesRecipientStore,
                // UI-test fixtures must not read or write the real
                // detector state on this Mac.
                stateStore: fixtureName == nil
                    ? FileUsageResetStateStore(directory: Self.allowanceDirectory())
                    : nil,
                enabled: { [weak self] in self?.preferences.notifyUsageReset ?? false },
                providerEnabled: { [weak self] provider in
                    self?.preferences.usageResetProviders.contains(provider) ?? false
                },
                nativeEnabled: { [weak self] in
                    self?.preferences.usageResetNativeNotification ?? false
                },
                messagesEnabled: { [weak self] in self?.preferences.usageResetMessages ?? false },
                didDeliver: { [weak self] delivery in
                    self?.model.recordUsageReset(delivery)
                }
            )
        }
        let statusMonitor: ProviderStatusMonitor? = switch fixtureName {
        case nil: ProviderStatusMonitor()
        case "signals": ProviderStatusMonitor(requester: UITestStatusRequester())
        default: nil
        }
        if fixtureName == nil {
            // A release that changes hook-processing logic must not ship
            // silently inert for existing users until they happen to
            // reopen Setup and click Repair (hit by hand during v0.5.3).
            try? HelperInstaller(
                sourceURL: Self.embeddedHelperSourceURL(),
                destinationURL: HelperInstaller.defaultDestination
            ).refreshIfNeeded()
        }
        let widgetIntegrationManagers: [any ProviderIntegrationManaging] = fixtureName == nil
            ? [
                ClaudeIntegrationManager(
                    settingsURL: FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".claude/settings.json"),
                    helperURL: HelperInstaller.defaultDestination
                ),
                CodexIntegrationManager(
                    hooksURL: FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".codex/hooks.json"),
                    helperURL: HelperInstaller.defaultDestination
                ),
                CursorIntegrationManager(
                    hooksURL: FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".cursor/hooks.json"),
                    helperURL: HelperInstaller.defaultDestination
                )
            ]
            : []
        model = AppModel(
            store: store,
            processMonitor: DarwinProcessMonitor(),
            activator: activator,
            allowanceCoordinator: makeAllowanceCoordinator(fixtureName: fixtureName),
            notifier: notificationService,
            resetAlerts: usageResetCoordinator,
            statusMonitor: statusMonitor,
            codexSessionDiscoverer: fixtureName == nil
                ? makeCodexSessionDiscoverer()
                : nil,
            widgetSnapshotWriter: fixtureName == nil ? AppGroupSnapshotWriter() : nil,
            widgetTimelineReloader: fixtureName == nil ? SystemWidgetTimelineReloader() : nil,
            installedProviders: fixtureName == nil ? {
                Dictionary(uniqueKeysWithValues: widgetIntegrationManagers.map { manager in
                    var installed = (try? manager.status().installed) ?? false
                    // Self-heal: a provider's hook entries can vanish out
                    // from under us if something external rewrites the
                    // shared config file (e.g. the host app's own settings
                    // persistence), the same class of problem the v0.5.8
                    // helper-binary refresh addressed for the binary
                    // itself. Only repair when the user previously wanted
                    // this installed (true) — never for a provider they
                    // never configured (nil) or explicitly removed
                    // (false); see integrationEnabledKey(for:).
                    let key = Self.integrationEnabledKey(for: manager.provider)
                    let userEnabled = UserDefaults.standard.object(forKey: key) as? Bool
                    if userEnabled == nil, installed {
                        // Migration for users who already had this working
                        // before this key existed: seed intent from
                        // observed state so future wipes get self-healed
                        // without requiring a manual Setup visit. Only
                        // seeds when currently installed — never infers
                        // intent from an absent config, which is
                        // indistinguishable from "never configured".
                        UserDefaults.standard.set(true, forKey: key)
                    } else if !installed, userEnabled == true {
                        try? manager.repair()
                        installed = (try? manager.status().installed) ?? false
                    }
                    return (manager.provider, installed)
                })
            } : nil
        )

        if fixtureName != nil {
            let suiteName = "\(ProductMetadata.bundleIdentifier).ui-tests.\(ProcessInfo.processInfo.processIdentifier)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            if let visualQA {
                defaults.set(visualQA.glassClarity, forKey: "glassClarity")
            }
            if fixtureName == "allowance-unavailable" {
                defaults.set(true, forKey: "codexUsageEnabled")
            }
            if fixtureName == "signals" {
                defaults.set(true, forKey: "codexUsageEnabled")
                defaults.set(true, forKey: "serviceStatusEnabled")
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
        if fixtureName == nil {
            let result = registerGlobalHotKey(preferences.globalShortcut)
            if result != .registered {
                NSLog("AgenticGlow: failed to register the configured global shortcut")
            }
        }
        model.start()
        notificationService?.start()
        Task {
            await model.setUsageEnabled(preferences.codexUsageEnabled, provider: .codex)
            await model.setUsageEnabled(preferences.claudeUsageEnabled, provider: .claude)
            await model.setServiceStatusEnabled(preferences.serviceStatusEnabled)
        }

        if fixtureName == nil {
            Task {
                await updateViewModel.check(
                    manual: false,
                    automaticEnabled: preferences.automaticUpdateChecks
                )
            }
        }

        let shouldReopenSetupAfterRestart = fixtureName == nil
            && UserDefaults.standard.bool(forKey: "reopenSetupAfterRestart")
        if shouldReopenSetupAfterRestart {
            UserDefaults.standard.removeObject(forKey: "reopenSetupAfterRestart")
        }
        if fixtureName == "setup-repair" {
            showSetupWindow()
        } else if fixtureName == nil,
                  !UserDefaults.standard.bool(forKey: "completedSetup") || shouldReopenSetupAfterRestart {
            showSetupWindow()
        }
        if fixtureName != nil,
           CommandLine.arguments.contains("--ui-test-open-popover") {
            DispatchQueue.main.async { [weak self] in
                self?.showUITestSessionWindow()
            }
        }
        if visualQA?.opensPopover == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.statusItemController.showPopoverForVisualQA()
            }
        }
        if CommandLine.arguments.contains("--ui-test-celebrate") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.model.triggerWeeklyResetForUITest()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        statusItemController.stop()
        reduceMotionObserver.stop()
        usageAvailabilityObserver.stop()
        unregisterGlobalHotKey()
    }

    /// Handles agenticglow:// links, currently only sent by the widget.
    /// Parsing lives in the pure, tested WidgetDeepLink; this is just the
    /// thin system-call glue that receives the Apple Event and routes
    /// through AppModel's existing methods.
    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString),
            let link = WidgetDeepLink.parse(url)
        else { return }
        route(link)
    }

    private func route(_ link: WidgetDeepLink) {
        guard let model, let statusItemController else { return }
        switch link {
        case .openApp:
            statusItemController.showPopoverForVisualQA()
        case let .openSession(provider, sessionID):
            if let session = model.resolved.sessions.first(where: {
                $0.provider == provider && $0.sessionID == sessionID
            }) {
                model.activate(session)
            }
            statusItemController.showPopoverForVisualQA()
        }
    }

    func makeSettingsView() -> some View {
        SettingsView(
            preferences: preferences,
            updates: updateViewModel,
            launchAtLogin: launchAtLogin,
            openIntegrations: { [weak self] in self?.showSetupWindow() },
            serviceStatusChanged: { [weak self] enabled in
                Task { await self?.model.setServiceStatusEnabled(enabled) }
            },
            notificationsDenied: { [notificationClient] in
                await notificationClient.isDenied()
            },
            settingsPresentationChanged: { [weak self] isPresented in
                self?.statusItemController.setSettingsPresented(isPresented)
            },
            registerGlobalShortcut: { [weak self] shortcut in
                guard let self else { return .unavailable }
                let result = self.registerGlobalHotKey(shortcut)
                if result == .registered {
                    self.preferences.globalShortcut = shortcut
                }
                return result
            },
            messagesRecipient: MessagesRecipientBinding(
                load: { [messagesRecipientStore] in try? messagesRecipientStore.load() },
                save: { [messagesRecipientStore] value in
                    do {
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            try messagesRecipientStore.delete()
                        } else {
                            try messagesRecipientStore.save(trimmed)
                        }
                        return nil
                    } catch {
                        return error.localizedDescription
                    }
                }
            ),
            sendTestUsageResetAlert: { [weak self] in
                // Test copy is provider-neutral in its own right, but the
                // pipeline is per provider, so use whichever the user has
                // reset alerts turned on for.
                guard let self else { return }
                let provider = AgentProvider.menuBarTintOrder.first {
                    self.preferences.usageResetProviders.contains($0)
                } ?? .codex
                self.usageResetCoordinator?.sendTestAlert(provider: provider)
            }
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

    private func relaunch() async -> Bool {
        UserDefaults.standard.set(true, forKey: "reopenSetupAfterRestart")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        do {
            _ = try await NSWorkspace.shared.openApplication(
                at: Bundle.main.bundleURL,
                configuration: configuration
            )
            NSApp.terminate(nil)
            return true
        } catch {
            // Relaunch failed — stay running rather than leaving no
            // app at all. The flag would otherwise force-open Setup
            // on some unrelated future launch, so clear it too.
            UserDefaults.standard.removeObject(forKey: "reopenSetupAfterRestart")
            return false
        }
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
                popoverState: PopoverState(),
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
                cursor: models.cursor,
                onComplete: onComplete
            )
        }

        let helperInstaller = HelperInstaller(
            sourceURL: Self.embeddedHelperSourceURL(),
            destinationURL: HelperInstaller.defaultDestination
        )

        let claudeSettingsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        let codexHooksURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/hooks.json")
        let cursorHooksURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/hooks.json")

        let claudeManager = ClaudeIntegrationManager(
            settingsURL: claudeSettingsURL,
            helperURL: HelperInstaller.defaultDestination
        )
        let codexManager = CodexIntegrationManager(
            hooksURL: codexHooksURL,
            helperURL: HelperInstaller.defaultDestination
        )
        let cursorManager = CursorIntegrationManager(
            hooksURL: cursorHooksURL,
            helperURL: HelperInstaller.defaultDestination
        )

        let store = FileSessionStateStore(directory: FileSessionStateStore.defaultDirectory)
        let syntheticEventService = SyntheticEventService(store: store)

        let claudeExecutable = ExecutableLocator.locate("claude")
        let codexExecutable = ExecutableLocator.locate("codex")
        let cursorExecutable = ExecutableLocator.locate("cursor")

        let claudeModel = SetupViewModel(
            provider: .claude,
            executableURL: claudeExecutable,
            helperInstaller: helperInstaller,
            integration: claudeManager,
            syntheticEventService: syntheticEventService,
            lastEvent: { [weak model] in
                model?.resolved.sessions
                    .first { $0.provider == .claude }?.updatedAt
            },
            setIntegrationEnabled: {
                UserDefaults.standard.set($0, forKey: Self.integrationEnabledKey(for: .claude))
            },
            requestRestart: { [weak self] in
                await self?.relaunch() ?? false
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
            },
            setIntegrationEnabled: {
                UserDefaults.standard.set($0, forKey: Self.integrationEnabledKey(for: .codex))
            },
            requestRestart: { [weak self] in
                await self?.relaunch() ?? false
            }
        )

        let cursorModel = SetupViewModel(
            provider: .cursor,
            executableURL: cursorExecutable,
            helperInstaller: helperInstaller,
            integration: cursorManager,
            syntheticEventService: syntheticEventService,
            lastEvent: { [weak model] in
                model?.resolved.sessions
                    .first { $0.provider == .cursor }?.updatedAt
            },
            setIntegrationEnabled: {
                UserDefaults.standard.set($0, forKey: Self.integrationEnabledKey(for: .cursor))
            },
            requestRestart: { [weak self] in
                await self?.relaunch() ?? false
            }
        )

        return SetupView(
            claude: claudeModel,
            codex: codexModel,
            cursor: cursorModel,
            onComplete: onComplete
        )
    }

    /// Tracks whether the user explicitly wants a provider's hooks
    /// installed, independent of whether they currently are: nil (never
    /// set) means never configured through Setup, so self-heal must never
    /// auto-install it; false means the user explicitly removed it and
    /// self-heal must not fight that; true means it should exist, so a
    /// missing config (e.g. wiped by an external settings rewrite) is
    /// safe to silently repair. `status().installed` alone can't tell
    /// these three states apart since it only reads current file content.
    private static func integrationEnabledKey(for provider: AgentProvider) -> String {
        "\(provider.rawValue)IntegrationEnabled"
    }

    private static func embeddedHelperSourceURL() -> URL {
        Bundle.main.url(
            forResource: "agenticglow-event",
            withExtension: nil,
            subdirectory: "bin"
        ) ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/agenticglow-event")
    }

    private func performCleanRemoval() {
        let claudeSettingsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        let codexHooksURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/hooks.json")
        let cursorHooksURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/hooks.json")
        let helperDestination = HelperInstaller.defaultDestination

        try? ClaudeIntegrationManager(
            settingsURL: claudeSettingsURL,
            helperURL: helperDestination
        ).remove()
        try? CodexIntegrationManager(
            hooksURL: codexHooksURL,
            helperURL: helperDestination
        ).remove()
        try? CursorIntegrationManager(
            hooksURL: cursorHooksURL,
            helperURL: helperDestination
        ).remove()
        try? FileManager.default.removeItem(at: helperDestination)
    }

    private func configurePreferences(defaults: UserDefaults) {
        preferences.reconfigure(
            defaults: defaults,
            showTimerDidChange: { [weak self] showTimer in
                self?.model.showTimer = showTimer
            }
        )
        model.showTimer = preferences.showTimer
        updateViewModel = UpdateViewModel(defaults: defaults)
    }

    /// Local, private store for the normalized allowance cache and the
    /// reset detector's evidence. Both are per-provider state with the same
    /// lifetime, so they share one directory.
    private static func allowanceDirectory() -> URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
            .appendingPathComponent(ProductMetadata.displayName, isDirectory: true)
            .appendingPathComponent("Allowance", isDirectory: true)
    }

    private func makeAllowanceCoordinator(fixtureName: String?) -> AllowanceRefreshCoordinator {
        let directory = Self.allowanceDirectory()
        let codexAdapter: any AllowanceProviding
        if fixtureName == "signals" {
            codexAdapter = UITestAllowanceAdapter(provider: .codex)
        } else if fixtureName != nil {
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

    private func makeCodexSessionDiscoverer() -> (any CodexSessionDiscovering)? {
        guard let executable = ExecutableLocator.locate("codex") else { return nil }
        return CodexSessionDiscoveryAdapter(
            requester: CodexThreadListClient(executableURL: executable)
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
