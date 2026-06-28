import AppKit
import KlarityCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItemController: StatusItemController!
    private var reduceMotionObserver: ReduceMotionObserver!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel(
            store: FileSessionStateStore(directory: FileSessionStateStore.defaultDirectory),
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        statusItemController.stop()
        reduceMotionObserver.stop()
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
