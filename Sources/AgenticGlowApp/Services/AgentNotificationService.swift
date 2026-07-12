import Foundation
import UserNotifications
import AgenticGlowCore

@MainActor
protocol AgentNotifying: AnyObject {
    func sessionsNeedPermission(_ sessions: [SessionSnapshot])
    func allowanceUpdated(provider: AgentProvider, allowance: ProviderAllowance)
}

@MainActor
protocol UserNotificationScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func isAuthorized() async -> Bool
    func add(id: String, title: String, body: String, userInfo: [String: String]) async
    var clickHandler: (@MainActor ([String: String]) -> Void)? { get set }
}

/// Delivers permission and low-quota notifications. Decision logic stays in
/// AgenticGlowCore; this type only formats copy and talks to the scheduler.
@MainActor
final class AgentNotificationService: AgentNotifying {
    private let scheduler: any UserNotificationScheduling
    private let permissionEnabled: () -> Bool
    private let quotaEnabled: () -> Bool
    private let activate: (String) -> Void
    private var quotaTracker = QuotaAlertTracker()
    private var pending: Task<Void, Never>?

    init(
        scheduler: any UserNotificationScheduling,
        permissionEnabled: @escaping () -> Bool,
        quotaEnabled: @escaping () -> Bool,
        activate: @escaping (String) -> Void
    ) {
        self.scheduler = scheduler
        self.permissionEnabled = permissionEnabled
        self.quotaEnabled = quotaEnabled
        self.activate = activate
    }

    /// Call once at launch. Requests authorization up front so the first
    /// alert is never lost behind the system permission prompt.
    func start() {
        scheduler.clickHandler = { [weak self] userInfo in
            guard let bundleID = userInfo["sourceBundleID"] else { return }
            self?.activate(bundleID)
        }
        if permissionEnabled() || quotaEnabled() {
            enqueue { scheduler in
                _ = await scheduler.requestAuthorization()
            }
        }
    }

    func sessionsNeedPermission(_ sessions: [SessionSnapshot]) {
        guard permissionEnabled() else { return }
        for session in sessions {
            let userInfo = session.sourceBundleID.map { ["sourceBundleID": $0] } ?? [:]
            enqueue { scheduler in
                await scheduler.add(
                    id: "permission.\(session.id)",
                    title: "\(session.projectName) needs you",
                    body: "\(session.provider.notificationName) is waiting for permission.",
                    userInfo: userInfo
                )
            }
        }
    }

    func allowanceUpdated(provider: AgentProvider, allowance: ProviderAllowance) {
        guard quotaEnabled() else { return }
        for alert in quotaTracker.newAlerts(provider: provider, allowance: allowance) {
            let window = alert.window
            let windowName = window.label == "week" ? "Weekly window" : "5-hour window"
            enqueue { scheduler in
                await scheduler.add(
                    id: "quota.\(provider.rawValue).\(window.label)",
                    title: "\(provider.notificationName) usage running low",
                    body: "\(windowName): \(Int(window.percentLeft.rounded()))% left.",
                    userInfo: [:]
                )
            }
        }
    }

    /// Awaits all queued deliveries. Used by tests.
    func drain() async {
        await pending?.value
    }

    private func enqueue(_ deliver: @escaping @MainActor (any UserNotificationScheduling) async -> Void) {
        pending = Task { [previous = pending, scheduler] in
            await previous?.value
            await deliver(scheduler)
        }
    }
}

private extension AgentProvider {
    var notificationName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        }
    }
}

/// Real UNUserNotificationCenter wrapper. Kept behind a protocol so the
/// service is testable without the notification daemon.
/// @unchecked Sendable is sound: the only mutable state, clickHandler, is
/// MainActor-isolated.
final class UserNotificationCenterClient: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    @MainActor var clickHandler: (@MainActor ([String: String]) -> Void)?

    @MainActor
    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let payload = userInfo.reduce(into: [String: String]()) { result, entry in
            if let key = entry.key as? String, let value = entry.value as? String {
                result[key] = value
            }
        }
        completionHandler()
        Task { @MainActor [weak self] in
            self?.clickHandler?(payload)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(.banner)
    }
}

@MainActor
extension UserNotificationCenterClient: UserNotificationScheduling {
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func isAuthorized() async -> Bool {
        await authorizationStatus() == .authorized
    }

    func isDenied() async -> Bool {
        await authorizationStatus() == .denied
    }

    // Extract only the Sendable authorization status inside the completion
    // handler. Awaiting notificationSettings() directly would carry the
    // non-Sendable UNNotificationSettings across the MainActor boundary,
    // which fails to compile under the CI toolchain (Xcode 16.4).
    private func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func add(id: String, title: String, body: String, userInfo: [String: String]) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
