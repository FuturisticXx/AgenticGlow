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

    func testQuotaTrackerWarnsOnceWhileLow() {
        var tracker = QuotaAlertTracker()

        XCTAssertEqual(
            tracker.newAlerts(
                provider: .claude,
                allowance: allowance(currentUsed: 92)
            ).map(\.level),
            [.low]
        )
        XCTAssertEqual(
            tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 95)),
            []
        )
    }

    func testQuotaTrackerAlertsWhenLowWindowBecomesExhausted() {
        var tracker = QuotaAlertTracker()
        _ = tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 92))

        let alerts = tracker.newAlerts(
            provider: .claude,
            allowance: allowance(currentUsed: 100)
        )

        XCTAssertEqual(alerts.map(\.level), [.exhausted])
    }

    func testQuotaTrackerFirstObservationAtZeroEmitsOnlyExhausted() {
        var tracker = QuotaAlertTracker()

        let alerts = tracker.newAlerts(
            provider: .claude,
            allowance: allowance(currentUsed: 100)
        )

        XCTAssertEqual(alerts.map(\.level), [.exhausted])
    }

    func testQuotaTrackerIgnoresMovingResetTimestampDuringSameLowState() {
        var tracker = QuotaAlertTracker()
        let first = allowance(
            currentUsed: 95,
            currentResetAt: now.addingTimeInterval(3_600)
        )
        let moved = allowance(
            currentUsed: 95,
            currentResetAt: now.addingTimeInterval(3_900)
        )
        _ = tracker.newAlerts(provider: .claude, allowance: first)

        XCTAssertEqual(tracker.newAlerts(provider: .claude, allowance: moved), [])
    }

    func testQuotaTrackerStaysExhaustedUntilHealthyRecovery() {
        var tracker = QuotaAlertTracker()
        _ = tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 100))

        XCTAssertEqual(
            tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 95)),
            []
        )

        _ = tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 40))

        XCTAssertEqual(
            tracker.newAlerts(
                provider: .claude,
                allowance: allowance(currentUsed: 95)
            ).map(\.level),
            [.low]
        )
    }

    func testQuotaTrackerKeepsWindowsAndProvidersIndependent() {
        var tracker = QuotaAlertTracker()
        let bothLow = allowance(currentUsed: 95, weeklyUsed: 95)

        let codexAlerts = tracker.newAlerts(provider: .codex, allowance: bothLow)
        XCTAssertEqual(codexAlerts.map(\.window.label), ["5h", "week"])
        XCTAssertEqual(codexAlerts.map(\.level), [.low, .low])
        XCTAssertEqual(
            tracker.newAlerts(provider: .claude, allowance: bothLow).map(\.level),
            [.low, .low]
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

    private func allowance(
        currentUsed: Double?,
        currentResetAt: Date? = nil,
        weeklyUsed: Double? = 20,
        weeklyResetAt: Date? = nil
    ) -> ProviderAllowance {
        ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: currentUsed,
            currentResetAt: currentResetAt,
            weeklyPercentUsed: weeklyUsed,
            weeklyResetAt: weeklyResetAt,
            fetchedAt: now
        )
    }
}
