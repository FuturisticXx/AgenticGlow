import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class SessionDetailPresentationTests: XCTestCase {
    func testDetailIncludesCurrentStepAndSurface() {
        let session = session(phase: .usingTool, label: "Editing main.swift", surface: .cli)
        let detail = SessionDetailPresentation.detail(for: session, now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(detail.currentStep, "Editing main.swift")
        XCTAssertEqual(detail.surface, "CLI")
    }

    func testLastUpdatedShowsJustNowWithinFiveSeconds() {
        let session = session(phase: .idle, updatedAt: Date(timeIntervalSince1970: 97))
        let detail = SessionDetailPresentation.detail(for: session, now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(detail.lastUpdated, "just now")
    }

    func testLastUpdatedShowsSecondsBelowOneMinute() {
        let session = session(phase: .idle, updatedAt: Date(timeIntervalSince1970: 55))
        let detail = SessionDetailPresentation.detail(for: session, now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(detail.lastUpdated, "45s ago")
    }

    func testLastUpdatedRollsOverToMinutesAtOneMinute() {
        let session = session(phase: .idle, updatedAt: Date(timeIntervalSince1970: 40))
        let detail = SessionDetailPresentation.detail(for: session, now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(detail.lastUpdated, "1m ago")
    }

    func testLastUpdatedShowsMinutesBelowOneHour() {
        let session = session(phase: .idle, updatedAt: Date(timeIntervalSince1970: 0))
        let detail = SessionDetailPresentation.detail(for: session, now: Date(timeIntervalSince1970: 125))
        XCTAssertEqual(detail.lastUpdated, "2m ago")
    }

    func testLastUpdatedShowsHoursAtOneHourAndAbove() {
        let session = session(phase: .idle, updatedAt: Date(timeIntervalSince1970: 0))
        let detail = SessionDetailPresentation.detail(for: session, now: Date(timeIntervalSince1970: 7_260))
        XCTAssertEqual(detail.lastUpdated, "2h ago")
    }

    func testFailedIncludesExplanatoryNote() {
        let session = session(phase: .failed, label: "Running swift build")
        let detail = SessionDetailPresentation.detail(for: session, now: Date(timeIntervalSince1970: 100))

        XCTAssertNotNil(detail.note)
        XCTAssertEqual(detail.currentStep, "Running swift build", "failed keeps the last action as the current step")
    }

    func testNonFailedPhasesHaveNoNote() {
        for phase in [SessionPhase.idle, .thinking, .usingTool, .permission, .completed, .disconnected] {
            let detail = SessionDetailPresentation.detail(for: session(phase: phase), now: Date(timeIntervalSince1970: 100))
            XCTAssertNil(detail.note, "\(phase) should not carry the failed explanation")
        }
    }

    private func session(
        phase: SessionPhase,
        label: String = "Working",
        surface: SourceSurface = .cli,
        updatedAt: Date = Date(timeIntervalSince1970: 90)
    ) -> SessionSnapshot {
        SessionSnapshot(
            provider: .codex,
            surface: surface,
            sessionID: "session",
            phase: phase,
            label: label,
            projectName: "AgenticGlow",
            sourceBundleID: "com.apple.Terminal",
            elapsedSeconds: nil,
            updatedAt: updatedAt
        )
    }
}
