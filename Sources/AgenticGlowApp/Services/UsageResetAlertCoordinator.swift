import Foundation
import AgenticGlowCore

/// What actually happened for one delivered reset alert. Drives the
/// "Alert sent" line in the popover and nothing else.
struct UsageResetDelivery: Equatable, Sendable {
    let key: UsageWindowKey
    let detectedAt: Date
    let nativeDelivered: Bool
    let messagesOutcome: MessagesSendOutcome?

    var didDeliver: Bool {
        nativeDelivered || messagesOutcome == .sent
    }
}

@MainActor
protocol UsageResetAlerting: AnyObject {
    func allowanceObserved(provider: AgentProvider, state: AllowanceAvailability)
    func sendTestAlert(provider: AgentProvider)
}

/// Owns the exactly-once guarantee for reset alerts: it holds the detector,
/// persists its evidence after every round, and fans a detected reset out
/// to the notification channels the user turned on.
///
/// Delivery never feeds back into detection. A failed message does not
/// re-arm the alert, and a channel failure cannot stall the monitor.
@MainActor
final class UsageResetAlertCoordinator: UsageResetAlerting {
    private let scheduler: any UserNotificationScheduling
    private let messages: any MessagesSending
    private let recipientStore: any MessagesRecipientStoring
    private let enabled: () -> Bool
    private let providerEnabled: (AgentProvider) -> Bool
    private let nativeEnabled: () -> Bool
    private let messagesEnabled: () -> Bool
    private let now: () -> Date
    private let log: (String) -> Void
    private let didDeliver: (UsageResetDelivery) -> Void
    private let stateStore: (any UsageResetStateStoring)?
    private var detector: UsageResetDetector
    private var pending: Task<Void, Never>?

    init(
        scheduler: any UserNotificationScheduling,
        messages: any MessagesSending,
        recipientStore: any MessagesRecipientStoring,
        stateStore: (any UsageResetStateStoring)?,
        enabled: @escaping () -> Bool,
        providerEnabled: @escaping (AgentProvider) -> Bool,
        nativeEnabled: @escaping () -> Bool,
        messagesEnabled: @escaping () -> Bool,
        now: @escaping () -> Date = Date.init,
        log: @escaping (String) -> Void = { NSLog("AgenticGlow: %@", $0) },
        didDeliver: @escaping (UsageResetDelivery) -> Void = { _ in }
    ) {
        self.scheduler = scheduler
        self.messages = messages
        self.recipientStore = recipientStore
        self.stateStore = stateStore
        self.enabled = enabled
        self.providerEnabled = providerEnabled
        self.nativeEnabled = nativeEnabled
        self.messagesEnabled = messagesEnabled
        self.now = now
        self.log = log
        self.didDeliver = didDeliver
        // Restoring persisted evidence is what stops a relaunch during an
        // exhausted window from re-announcing a reset already delivered.
        detector = UsageResetDetector(evidence: (try? stateStore?.load()) ?? [:])
    }

    func allowanceObserved(provider: AgentProvider, state: AllowanceAvailability) {
        if case .off = state {
            detector.forget(provider: provider)
            persist()
            return
        }
        let observations = UsageWindowReader.observations(
            provider: provider,
            state: state,
            now: now()
        )
        let events = detector.evaluate(observations)
        persist()
        for event in events {
            log("\(event.key.provider.displayName) \(event.key.spokenWindowName) usage availability confirmed, reset transition detected")
            guard enabled(), providerEnabled(event.key.provider) else { continue }
            deliver(UsageResetAlert(event: event), detectedAt: event.detectedAt)
        }
    }

    func sendTestAlert(provider: AgentProvider) {
        deliver(
            UsageResetAlert(
                key: UsageWindowKey(provider: provider, windowLabel: UsageWindowKey.weeklyLabel),
                isTest: true
            ),
            detectedAt: now()
        )
    }

    /// Awaits all queued deliveries. Used by tests.
    func drain() async {
        await pending?.value
    }

    private func deliver(_ alert: UsageResetAlert, detectedAt: Date) {
        let wantsNative = nativeEnabled()
        let recipient = messagesEnabled() ? loadRecipient() : nil
        enqueue { [scheduler, messages, log, didDeliver] in
            if wantsNative {
                await scheduler.add(
                    id: alert.notificationID,
                    title: alert.title,
                    body: alert.body,
                    userInfo: [:]
                )
                log("Native notification delivered: \(alert.title)")
            }
            var messagesOutcome: MessagesSendOutcome?
            if let recipient {
                let outcome = await messages.send(recipient: recipient, body: alert.messageText)
                messagesOutcome = outcome
                switch outcome {
                case .sent:
                    // Deliberately no recipient in the log.
                    log("Messages notification delivered")
                case let .failed(reason):
                    log("Messages notification failed: \(reason)")
                }
            }
            // A test exercises the same pipeline but must never be
            // presented as a real reset in the popover.
            guard !alert.isTest else { return }
            didDeliver(UsageResetDelivery(
                key: alert.key,
                detectedAt: detectedAt,
                nativeDelivered: wantsNative,
                messagesOutcome: messagesOutcome
            ))
        }
    }

    private func loadRecipient() -> String? {
        guard let recipient = try? recipientStore.load(),
              MessagesScript.isValidRecipient(recipient)
        else {
            log("Messages notification skipped: no recipient configured")
            return nil
        }
        return recipient
    }

    private func persist() {
        do {
            try stateStore?.save(detector.evidence)
        } catch {
            // A missed write only risks one duplicate alert after a
            // relaunch, which is not worth interrupting monitoring for.
            log("Usage reset state could not be saved")
        }
    }

    private func enqueue(_ deliver: @escaping @MainActor () async -> Void) {
        pending = Task { [previous = pending] in
            await previous?.value
            await deliver()
        }
    }
}
