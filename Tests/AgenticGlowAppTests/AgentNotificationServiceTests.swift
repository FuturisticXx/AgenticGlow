import Foundation
import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

@MainActor
final class AgentNotificationServiceTests: XCTestCase {
    func testPermissionTransitionDeliversNotificationWithSourceBundle() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler)

        service.sessionsNeedPermission([session(projectName: "Example")])
        await service.drain()

        XCTAssertEqual(scheduler.added.count, 1)
        XCTAssertEqual(scheduler.added.first?.title, "Example needs you")
        XCTAssertEqual(scheduler.added.first?.body, "Claude is waiting for permission.")
        XCTAssertEqual(
            scheduler.added.first?.userInfo["sourceBundleID"],
            "com.anthropic.claudefordesktop"
        )
    }

    func testPermissionToggleOffSuppressesDelivery() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler, permissionEnabled: false)

        service.sessionsNeedPermission([session(projectName: "Example")])
        await service.drain()

        XCTAssertEqual(scheduler.added, [])
    }

    func testQuotaLowIncludesResetTime() async {
        let scheduler = FakeScheduler()
        let service = makeService(
            scheduler: scheduler,
            resetTime: { _ in "12:50 AM" }
        )

        service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 92))
        await service.drain()

        XCTAssertEqual(scheduler.added.count, 1)
        XCTAssertEqual(scheduler.added.first?.id, "quota.claude.5h")
        XCTAssertEqual(scheduler.added.first?.title, "Claude usage running low")
        XCTAssertEqual(
            scheduler.added.first?.body,
            "5-hour window: 8% left. Resets at 12:50 AM."
        )
    }

    func testQuotaToggleOffSuppressesDelivery() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler, quotaEnabled: false)

        service.allowanceUpdated(provider: .codex, allowance: allowance(currentUsed: 92))
        await service.drain()

        XCTAssertEqual(scheduler.added, [])
    }

    func testQuotaExhaustedReplacesLowNotification() async {
        let scheduler = FakeScheduler()
        let service = makeService(
            scheduler: scheduler,
            resetTime: { _ in "12:50 AM" }
        )

        service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 92))
        service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 100))
        await service.drain()

        XCTAssertEqual(
            scheduler.added.map(\.id),
            ["quota.claude.5h", "quota.claude.5h"]
        )
        XCTAssertEqual(scheduler.added.last?.title, "Claude 5-hour usage exhausted")
        XCTAssertEqual(scheduler.added.last?.body, "Available again at 12:50 AM.")
    }

    func testQuotaExhaustedWithoutResetTimeUsesFallback() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler)

        service.allowanceUpdated(
            provider: .codex,
            allowance: allowance(currentUsed: 100, currentResetAt: nil)
        )
        await service.drain()

        XCTAssertEqual(scheduler.added.first?.title, "Codex 5-hour usage exhausted")
        XCTAssertEqual(
            scheduler.added.first?.body,
            "No usage remaining in this window."
        )
    }

    func testWeeklyExhaustedUsesWeeklyTitleAndSameWindowID() async {
        let scheduler = FakeScheduler()
        let service = makeService(
            scheduler: scheduler,
            resetTime: { _ in "8:00 PM" }
        )

        service.allowanceUpdated(
            provider: .claude,
            allowance: allowance(currentUsed: 20, weeklyUsed: 100)
        )
        await service.drain()

        XCTAssertEqual(scheduler.added.first?.id, "quota.claude.week")
        XCTAssertEqual(scheduler.added.first?.title, "Claude weekly usage exhausted")
        XCTAssertEqual(
            scheduler.added.first?.body,
            "Available again at 8:00 PM."
        )
    }

    func testRepeatedExhaustedReadingsScheduleOnce() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler)

        service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 100))
        service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 100))
        await service.drain()

        XCTAssertEqual(scheduler.added.count, 1)
    }

    func testClickActivatesSourceApplication() {
        let scheduler = FakeScheduler()
        var activated: [String] = []
        let service = makeService(
            scheduler: scheduler,
            activate: { activated.append($0) }
        )

        service.start()
        scheduler.clickHandler?(["sourceBundleID": "com.apple.Terminal"])

        XCTAssertEqual(activated, ["com.apple.Terminal"])
    }

    func testStartRequestsAuthorizationWhenAnyToggleIsOn() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler, permissionEnabled: false)

        service.start()
        await service.drain()

        XCTAssertEqual(scheduler.authorizationRequests, 1)
    }

    func testStartSkipsAuthorizationWhenBothTogglesAreOff() async {
        let scheduler = FakeScheduler()
        let service = makeService(
            scheduler: scheduler,
            permissionEnabled: false,
            quotaEnabled: false
        )

        service.start()
        await service.drain()

        XCTAssertEqual(scheduler.authorizationRequests, 0)
    }

    private func makeService(
        scheduler: FakeScheduler,
        permissionEnabled: Bool = true,
        quotaEnabled: Bool = true,
        resetTime: @escaping (Date) -> String = { _ in "12:50 AM" },
        activate: @escaping (String) -> Void = { _ in }
    ) -> AgentNotificationService {
        AgentNotificationService(
            scheduler: scheduler,
            permissionEnabled: { permissionEnabled },
            quotaEnabled: { quotaEnabled },
            resetTime: resetTime,
            activate: activate
        )
    }

    private func session(projectName: String) -> SessionSnapshot {
        SessionSnapshot(
            provider: .claude,
            surface: .desktop,
            sessionID: "s",
            phase: .permission,
            label: "Awaiting permission",
            projectName: projectName,
            sourceBundleID: "com.anthropic.claudefordesktop",
            elapsedSeconds: nil,
            updatedAt: Date()
        )
    }

    private func allowance(
        currentUsed: Double?,
        currentResetAt: Date? = Date(timeIntervalSince1970: 1_783_101_600),
        weeklyUsed: Double? = 20,
        weeklyResetAt: Date? = Date(timeIntervalSince1970: 1_783_616_400)
    ) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentUsed,
            currentResetAt: currentResetAt,
            weeklyPercentUsed: weeklyUsed,
            weeklyResetAt: weeklyResetAt,
            fetchedAt: Date(timeIntervalSince1970: 1_783_099_000)
        )
    }
}

@MainActor
private final class FakeScheduler: UserNotificationScheduling {
    struct Added: Equatable {
        let id: String
        let title: String
        let body: String
        let userInfo: [String: String]
    }

    private(set) var added: [Added] = []
    private(set) var authorizationRequests = 0
    var clickHandler: (@MainActor ([String: String]) -> Void)?

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return true
    }

    func isAuthorized() async -> Bool { true }

    func add(id: String, title: String, body: String, userInfo: [String: String]) async {
        added.append(Added(id: id, title: title, body: body, userInfo: userInfo))
    }
}
