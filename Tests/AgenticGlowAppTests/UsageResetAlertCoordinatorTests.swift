import Foundation
import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

@MainActor
final class UsageResetAlertCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testConfirmedResetDeliversExactlyOneAlert() async {
        let scheduler = RecordingScheduler()
        let coordinator = makeCoordinator(scheduler: scheduler)

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 1))
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 2))
        await coordinator.drain()

        XCTAssertEqual(scheduler.added.count, 1)
        XCTAssertEqual(scheduler.added.first?.id, "usageReset.codex.5h")
        XCTAssertEqual(scheduler.added.first?.title, "Codex Usage Reset")
        XCTAssertEqual(
            scheduler.added.first?.body,
            "Codex 5-hour usage has reset and is available again."
        )
    }

    func testStaleReadingAfterExhaustionDoesNotFakeAReset() async {
        let scheduler = RecordingScheduler()
        let coordinator = makeCoordinator(scheduler: scheduler)

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        // The same allowance replayed from cache after a failed fetch. It
        // still reads 0% used for the weekly window, which must not count.
        coordinator.allowanceObserved(
            provider: .codex,
            state: .available(allowance(currentPercentUsed: 0), .stale)
        )
        coordinator.allowanceObserved(provider: .codex, state: .unavailable("offline"))
        await coordinator.drain()

        XCTAssertEqual(scheduler.added, [])
    }

    func testRelaunchDoesNotRepeatAnAlreadyDeliveredAlert() async {
        let store = InMemoryUsageResetStateStore()
        let first = RecordingScheduler()
        let before = makeCoordinator(scheduler: first, stateStore: store)

        before.allowanceObserved(provider: .codex, state: exhausted)
        before.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await before.drain()
        XCTAssertEqual(first.added.count, 1)

        let second = RecordingScheduler()
        let afterRelaunch = makeCoordinator(scheduler: second, stateStore: store)
        afterRelaunch.allowanceObserved(provider: .codex, state: available(percentUsed: 3))
        await afterRelaunch.drain()

        XCTAssertEqual(second.added, [])
    }

    func testRelaunchDuringExhaustionStillDeliversTheReset() async {
        let store = InMemoryUsageResetStateStore()
        let before = makeCoordinator(scheduler: RecordingScheduler(), stateStore: store)
        before.allowanceObserved(provider: .codex, state: exhausted)
        await before.drain()

        let scheduler = RecordingScheduler()
        let afterRelaunch = makeCoordinator(scheduler: scheduler, stateStore: store)
        afterRelaunch.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await afterRelaunch.drain()

        XCTAssertEqual(scheduler.added.count, 1)
    }

    func testDisabledProviderIsDetectedButNotAnnounced() async {
        let scheduler = RecordingScheduler()
        let coordinator = makeCoordinator(scheduler: scheduler, providerEnabled: { _ in false })

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await coordinator.drain()

        XCTAssertEqual(scheduler.added, [])
    }

    func testMasterToggleOffSuppressesDelivery() async {
        let scheduler = RecordingScheduler()
        let coordinator = makeCoordinator(scheduler: scheduler, enabled: false)

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await coordinator.drain()

        XCTAssertEqual(scheduler.added, [])
    }

    func testTurningUsageOffForgetsExhaustion() async {
        let scheduler = RecordingScheduler()
        let coordinator = makeCoordinator(scheduler: scheduler)

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.allowanceObserved(provider: .codex, state: .off)
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await coordinator.drain()

        XCTAssertEqual(scheduler.added, [])
    }

    func testMessagesFailureStillLeavesTheNativeAlertDelivered() async {
        let scheduler = RecordingScheduler()
        let messages = RecordingMessages(outcome: .failed("Automation permission denied"))
        var deliveries: [UsageResetDelivery] = []
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            messages: messages,
            messagesEnabled: true,
            didDeliver: { deliveries.append($0) }
        )

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await coordinator.drain()

        XCTAssertEqual(scheduler.added.count, 1)
        XCTAssertEqual(messages.sent.count, 1)
        XCTAssertEqual(deliveries.first?.nativeDelivered, true)
        XCTAssertEqual(deliveries.first?.messagesOutcome, .failed("Automation permission denied"))
        XCTAssertEqual(deliveries.first?.didDeliver, true)
    }

    func testMessagesBodyMatchesTheRequestedWording() async {
        let messages = RecordingMessages()
        let coordinator = makeCoordinator(
            scheduler: RecordingScheduler(),
            messages: messages,
            messagesEnabled: true
        )

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await coordinator.drain()

        XCTAssertEqual(
            messages.sent.first?.body,
            "AgenticGlow: Codex 5-hour usage has reset and is available again."
        )
        XCTAssertEqual(messages.sent.first?.recipient, "+15550000000")
    }

    func testMessagesIsSkippedWithoutAConfiguredRecipient() async {
        let messages = RecordingMessages()
        let coordinator = makeCoordinator(
            scheduler: RecordingScheduler(),
            messages: messages,
            recipientStore: InMemoryMessagesRecipientStore(),
            messagesEnabled: true
        )

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await coordinator.drain()

        XCTAssertEqual(messages.sent, [])
    }

    func testTestAlertUsesTheRealPipelineWithoutTouchingDetection() async {
        let scheduler = RecordingScheduler()
        var deliveries: [UsageResetDelivery] = []
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            didDeliver: { deliveries.append($0) }
        )

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.sendTestAlert(provider: .codex)
        await coordinator.drain()

        XCTAssertEqual(scheduler.added.count, 1)
        XCTAssertTrue(scheduler.added.first?.title.contains("test") == true)
        // A test is not a reset, so it must not appear in the popover.
        XCTAssertEqual(deliveries, [])

        // And it must not have disturbed the persisted exhaustion.
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await coordinator.drain()
        XCTAssertEqual(scheduler.added.count, 2)
        XCTAssertEqual(scheduler.added.last?.title, "Codex Usage Reset")
    }

    func testNativeChannelOffStillSendsMessages() async {
        let scheduler = RecordingScheduler()
        let messages = RecordingMessages()
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            messages: messages,
            nativeEnabled: false,
            messagesEnabled: true
        )

        coordinator.allowanceObserved(provider: .codex, state: exhausted)
        coordinator.allowanceObserved(provider: .codex, state: available(percentUsed: 0))
        await coordinator.drain()

        XCTAssertEqual(scheduler.added, [])
        XCTAssertEqual(messages.sent.count, 1)
    }

    // MARK: Helpers

    private var exhausted: AllowanceAvailability {
        .available(allowance(currentPercentUsed: 100), .fresh)
    }

    private func available(percentUsed: Double) -> AllowanceAvailability {
        .available(allowance(currentPercentUsed: percentUsed), .fresh)
    }

    private func allowance(currentPercentUsed: Double) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentPercentUsed,
            currentResetAt: now.addingTimeInterval(600),
            // Held far from either edge so only the current window can
            // ever produce a transition in these tests.
            weeklyPercentUsed: 50,
            weeklyResetAt: now.addingTimeInterval(6 * 86_400),
            fetchedAt: now
        )
    }

    private func makeCoordinator(
        scheduler: RecordingScheduler,
        messages: RecordingMessages = RecordingMessages(),
        recipientStore: any MessagesRecipientStoring =
            InMemoryMessagesRecipientStore(recipient: "+15550000000"),
        stateStore: (any UsageResetStateStoring)? = InMemoryUsageResetStateStore(),
        enabled: Bool = true,
        providerEnabled: @escaping (AgentProvider) -> Bool = { _ in true },
        nativeEnabled: Bool = true,
        messagesEnabled: Bool = false,
        didDeliver: @escaping (UsageResetDelivery) -> Void = { _ in }
    ) -> UsageResetAlertCoordinator {
        UsageResetAlertCoordinator(
            scheduler: scheduler,
            messages: messages,
            recipientStore: recipientStore,
            stateStore: stateStore,
            enabled: { enabled },
            providerEnabled: providerEnabled,
            nativeEnabled: { nativeEnabled },
            messagesEnabled: { messagesEnabled },
            now: { self.now },
            log: { _ in },
            didDeliver: didDeliver
        )
    }
}

@MainActor
private final class RecordingScheduler: UserNotificationScheduling {
    struct Added: Equatable {
        let id: String
        let title: String
        let body: String
    }

    private(set) var added: [Added] = []
    var clickHandler: (@MainActor ([String: String]) -> Void)?

    func requestAuthorization() async -> Bool { true }
    func isAuthorized() async -> Bool { true }

    func add(id: String, title: String, body: String, userInfo: [String: String]) async {
        added.append(Added(id: id, title: title, body: body))
    }
}

private final class RecordingMessages: MessagesSending, @unchecked Sendable {
    struct Sent: Equatable {
        let recipient: String
        let body: String
    }

    private let lock = NSLock()
    private let outcome: MessagesSendOutcome
    private var storage: [Sent] = []

    var sent: [Sent] { lock.withLock { storage } }

    init(outcome: MessagesSendOutcome = .sent) {
        self.outcome = outcome
    }

    func send(recipient: String, body: String) async -> MessagesSendOutcome {
        lock.withLock { storage.append(Sent(recipient: recipient, body: body)) }
        return outcome
    }
}

private final class InMemoryUsageResetStateStore: UsageResetStateStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var evidence: [UsageWindowKey: UsageWindowEvidence] = [:]

    func load() throws -> [UsageWindowKey: UsageWindowEvidence] { lock.withLock { evidence } }

    func save(_ evidence: [UsageWindowKey: UsageWindowEvidence]) throws {
        lock.withLock { self.evidence = evidence }
    }
}
