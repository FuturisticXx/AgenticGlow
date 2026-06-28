import AppKit
import SwiftUI
import KlarityCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItemController: StatusItemController!
    private var reduceMotionObserver: ReduceMotionObserver!
    private var preferences: PreferencesStore!
    private var updateViewModel: UpdateViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            openIntegrations: {}
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

        // Skip preferences and updates in UI test mode
        if UITestFixtureFactory.events(arguments: CommandLine.arguments) == nil {
            preferences = PreferencesStore()
            updateViewModel = UpdateViewModel()

            Task {
                await updateViewModel.check(
                    manual: false,
                    automaticEnabled: preferences.automaticUpdateChecks
                )
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
            updates: updateViewModel
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
