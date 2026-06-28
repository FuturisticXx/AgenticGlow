import AppKit
import KlarityCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItemController: StatusItemController!

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
        updateReduceMotion()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        statusItemController.stop()
    }

    @objc private func accessibilityDisplayOptionsDidChange() {
        updateReduceMotion()
    }

    private func updateReduceMotion() {
        model.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
