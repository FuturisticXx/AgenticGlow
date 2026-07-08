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

    func testQuotaAlertFiresOncePerWindowWithWindowCopy() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler)
        let low = allowance(currentUsed: 92)

        service.allowanceUpdated(provider: .codex, allowance: low)
        service.allowanceUpdated(provider: .codex, allowance: low)
        await service.drain()

        XCTAssertEqual(scheduler.added.count, 1)
        XCTAssertEqual(scheduler.added.first?.title, "Codex usage running low")
        XCTAssertEqual(scheduler.added.first?.body, "5-hour window: 8% left.")
    }

    func testQuotaToggleOffSuppressesDelivery() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler, quotaEnabled: false)

        service.allowanceUpdated(provider: .codex, allowance: allowance(currentUsed: 92))
        await service.drain()

        XCTAssertEqual(scheduler.added, [])
    }

    func testWeeklyWindowUsesWeeklyCopy() async {
        let scheduler = FakeScheduler()
        let service = makeService(scheduler: scheduler)

        service.allowanceUpdated(
            provider: .claude,
            allowance: allowance(currentUsed: 20, weeklyUsed: 95)
        )
        await service.drain()

        XCTAssertEqual(scheduler.added.first?.title, "Claude usage running low")
        XCTAssertEqual(scheduler.added.first?.body, "Weekly window: 5% left.")
    }

    func testClickActivatesSourceApplication() {
        let scheduler = FakeScheduler()
        var activated: [String] = []
        let service = makeService(scheduler: scheduler) { activated.append($0) }

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
        activate: @escaping (String) -> Void = { _ in }
    ) -> AgentNotificationService {
        AgentNotificationService(
            scheduler: scheduler,
            permissionEnabled: { permissionEnabled },
            quotaEnabled: { quotaEnabled },
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
        weeklyUsed: Double? = 20
    ) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentUsed,
            currentResetAt: Date(timeIntervalSince1970: 1_783_101_600),
            weeklyPercentUsed: weeklyUsed,
            weeklyResetAt: Date(timeIntervalSince1970: 1_783_616_400),
            fetchedAt: Date(timeIntervalSince1970: 1_783_099_000)
        )
    }
}

@MainActor
private final class FakeScheduler: UserNotificationScheduling {
    struct Added: Equatable {
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
        added.append(Added(title: title, body: body, userInfo: userInfo))
    }
}
