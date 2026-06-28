import SwiftUI

@main
struct KlarityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            appDelegate.makeSettingsView()
        }
    }
}
