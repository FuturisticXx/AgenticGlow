import AppKit
import SwiftUI
import KlarityCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItemController: StatusItemController!
    private var reduceMotionObserver: ReduceMotionObserver!
    private var setupWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Support noninteractive clean-removal mode
        if CommandLine.arguments.contains("--remove-integrations") {
            performCleanRemoval()
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        model = AppModel(
            store: FileSessionStateStore(directory: FileSessionStateStore.defaultDirectory),
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

        // Show setup window on first launch
        if !UserDefaults.standard.bool(forKey: "completedSetup") {
            showSetupWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        statusItemController.stop()
        reduceMotionObserver.stop()
    }

    func makeSettingsView() -> some View {
        Text("Settings")
            .padding()
    }

    private func showSetupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Klarity Setup"
        window.center()
        window.contentViewController = NSHostingController(rootView: makeSetupView {
            UserDefaults.standard.set(true, forKey: "completedSetup")
            self.setupWindow?.close()
            self.setupWindow = nil
        })
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupWindow = window
    }

    private func makeSetupView(onComplete: @escaping () -> Void) -> some View {
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
        try? FileManager.default.removeItem(
            at: helperDestination.deletingLastPathComponent()
        )
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
