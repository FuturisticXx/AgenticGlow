import Foundation

/// Copy for one reset alert, shared by every delivery channel so the
/// notification and the message can never drift apart.
public struct UsageResetAlert: Equatable, Sendable {
    public let key: UsageWindowKey
    public let title: String
    public let body: String
    public let messageText: String
    public let isTest: Bool

    /// Stable per window, so a second reset of the same window replaces the
    /// earlier banner instead of stacking another one in Notification Center.
    public var notificationID: String {
        "usageReset.\(key.provider.rawValue).\(key.windowLabel)"
    }

    public init(event: UsageResetEvent) {
        self.init(key: event.key, isTest: false)
    }

    public init(key: UsageWindowKey, isTest: Bool) {
        let provider = key.provider.displayName
        let window = key.spokenWindowName
        self.key = key
        self.isTest = isTest
        if isTest {
            title = "AgenticGlow test alert"
            body = "This is how a \(provider) usage reset alert will look."
            messageText = "AgenticGlow test alert: this is how a \(provider) usage reset alert will look."
        } else {
            title = "\(provider) Usage Reset"
            body = "\(provider) \(window) usage has reset and is available again."
            messageText = "AgenticGlow: \(provider) \(window) usage has reset and is available again."
        }
    }
}
