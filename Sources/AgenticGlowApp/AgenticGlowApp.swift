import SwiftUI

@main
struct AgenticGlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            appDelegate.makeSettingsView()
        }
    }
}
