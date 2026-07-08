import Foundation
import XCTest
@testable import AgenticGlowCore

final class NotificationPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)

    func testTransitionIntoPermissionFires() {
        let session = snapshot(sessionID: "a", phase: .permission)
        let fired = NotificationPolicy.newlyAwaitingPermission(
            previousPhases: [session.id: .usingTool],
            sessions: [session]
        )

        XCTAssertEqual(fired, [session])
    }

    func testSteadyPermissionDoesNotRefire() {
        let session = snapshot(sessionID: "a", phase: .permission)
        let fired = NotificationPolicy.newlyAwaitingPermission(
            previousPhases: [session.id: .permission],
            sessions: [session]
        )

        XCTAssertEqual(fired, [])
    }

    func testUnseenPermissionSessionFires() {
        let session = snapshot(sessionID: "a", phase: .permission)
        let fired = NotificationPolicy.newlyAwaitingPermission(
            previousPhases: [:],
            sessions: [session]
        )

        XCTAssertEqual(fired, [session])
    }

    func testNonPermissionSessionsNeverFire() {
        let fired = NotificationPolicy.newlyAwaitingPermission(
            previousPhases: [:],
            sessions: [snapshot(sessionID: "a", phase: .thinking)]
        )

        XCTAssertEqual(fired, [])
    }

    func testQuotaTrackerFiresOncePerWindow() {
        var tracker = QuotaAlertTracker()
        let low = allowance(currentUsed: 95, currentResetAt: now.addingTimeInterval(3_600))

        XCTAssertEqual(
            tracker.newAlerts(provider: .codex, allowance: low).map(\.label),
            ["5h"]
        )
        XCTAssertEqual(tracker.newAlerts(provider: .codex, allowance: low), [])
    }

    func testQuotaTrackerRefiresForNewWindow() {
        var tracker = QuotaAlertTracker()
        let first = allowance(currentUsed: 95, currentResetAt: now.addingTimeInterval(3_600))
        let second = allowance(currentUsed: 95, currentResetAt: now.addingTimeInterval(7_200))

        _ = tracker.newAlerts(provider: .codex, allowance: first)

        XCTAssertEqual(
            tracker.newAlerts(provider: .codex, allowance: second).map(\.label),
            ["5h"]
        )
    }

    func testQuotaTrackerKeepsProvidersIndependent() {
        var tracker = QuotaAlertTracker()
        let low = allowance(currentUsed: 95, currentResetAt: now.addingTimeInterval(3_600))

        _ = tracker.newAlerts(provider: .codex, allowance: low)

        XCTAssertEqual(
            tracker.newAlerts(provider: .claude, allowance: low).map(\.label),
            ["5h"]
        )
    }

    func testQuotaTrackerIgnoresHealthyAllowance() {
        var tracker = QuotaAlertTracker()

        XCTAssertEqual(
            tracker.newAlerts(provider: .codex, allowance: allowance(currentUsed: 40)),
            []
        )
    }

    private func snapshot(sessionID: String, phase: SessionPhase) -> SessionSnapshot {
        SessionSnapshot(
            provider: .claude,
            surface: .desktop,
            sessionID: sessionID,
            phase: phase,
            label: "Working",
            projectName: "Example",
            sourceBundleID: "com.anthropic.claudefordesktop",
            elapsedSeconds: nil,
            updatedAt: now
        )
    }

    private func allowance(currentUsed: Double?, currentResetAt: Date? = nil) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentUsed,
            currentResetAt: currentResetAt,
            weeklyPercentUsed: 20,
            weeklyResetAt: nil,
            fetchedAt: now
        )
    }
}
