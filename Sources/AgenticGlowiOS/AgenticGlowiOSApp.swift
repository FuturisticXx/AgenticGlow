import SwiftUI
import UIKit
import AgenticGlowCore

/// The iPhone host for the AgenticGlow widget. It collects nothing itself:
/// the Mac remains the authoritative observer, and this app's whole job is
/// to keep the App Group cache the widget renders from as current as iOS
/// allows, and to say plainly how current that is.
@main
struct AgenticGlowiOSApp: App {
    @UIApplicationDelegateAdaptor(SyncAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            StatusView(model: appDelegate.syncModel)
                .onOpenURL { _ in
                    // Widget taps carry the desktop deep links. There is
                    // no Mac window to bring forward from here; opening
                    // the app, which shows the status, is the whole action.
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appDelegate.syncModel.refresh() }
            }
        }
    }
}

/// UIKit glue for the one thing SwiftUI cannot do: receive the silent
/// push CloudKit sends when the Mac publishes, and fetch on its behalf.
final class SyncAppDelegate: NSObject, UIApplicationDelegate {
    @MainActor let syncModel = SyncModel()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Silent pushes need no user permission and show nothing; this
        // only gives CloudKit a device token to deliver them to.
        application.registerForRemoteNotifications()
        Task { await syncModel.ensureSubscribed() }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await syncModel.refresh() ? .newData : .noData
    }
}
