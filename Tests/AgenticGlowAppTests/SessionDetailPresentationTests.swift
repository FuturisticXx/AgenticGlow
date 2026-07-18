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

    func testStartedIsNilWithoutAnActiveTurn() {
        let session = session(phase: .idle)
        let detail = SessionDetailPresentation.detail(for: session, now: Date(timeIntervalSince1970: 100))
        XCTAssertNil(detail.started)
    }

    func testStartedShowsClockTimeOnlyForSameDay() {
        let now = Date(timeIntervalSince1970: 100)
        let session = session(phase: .thinking, turnStartedAt: Date(timeIntervalSince1970: 40))
        let detail = SessionDetailPresentation.detail(for: session, now: now)

        let expected = Date(timeIntervalSince1970: 40).formatted(date: .omitted, time: .shortened)
        XCTAssertEqual(detail.started, expected)
    }

    func testStartedIncludesCalendarDateOnAnEarlierDay() {
        let now = Date(timeIntervalSince1970: 100)
        let earlierDay = now.addingTimeInterval(-2 * 24 * 60 * 60)
        let session = session(phase: .thinking, turnStartedAt: earlierDay)
        let detail = SessionDetailPresentation.detail(for: session, now: now)

        let expected = earlierDay.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        XCTAssertEqual(detail.started, expected)
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
        updatedAt: Date = Date(timeIntervalSince1970: 90),
        turnStartedAt: Date? = nil
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
            turnStartedAt: turnStartedAt,
            updatedAt: updatedAt
        )
    }
}
