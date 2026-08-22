import XCTest
@testable import AgenticGlowCore

final class WorkContextCopyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCopyIncludesPathHarnessModelPhaseAndTime() {
        let session = SessionSnapshot(
            provider: .cursor,
            surface: .desktop,
            sessionID: "one",
            phase: .thinking,
            label: "Working",
            projectName: "AgenticGlow",
            workingDirectory: "/tmp/AgenticGlow",
            sourceBundleID: nil,
            elapsedSeconds: 12,
            updatedAt: now,
            model: "grok-4.6"
        )
        let text = WorkContextCopy.text(for: session, now: now)
        XCTAssertTrue(text.contains("AgenticGlow"))
        XCTAssertTrue(text.contains("/tmp/AgenticGlow"))
        XCTAssertTrue(text.contains("Cursor"))
        XCTAssertTrue(text.contains("grok-4.6"))
        XCTAssertTrue(text.contains("Thinking"))
        XCTAssertFalse(text.contains("prompt"))
    }

    func testRevealRequiresANormalizedPath() {
        let valid = SessionSnapshot(
            provider: .cursor,
            surface: .desktop,
            sessionID: "one",
            phase: .thinking,
            label: "Working",
            projectName: "AgenticGlow",
            workingDirectory: "/tmp/AgenticGlow",
            sourceBundleID: nil,
            elapsedSeconds: 12,
            updatedAt: now
        )
        let missing = SessionSnapshot(
            provider: .cursor,
            surface: .desktop,
            sessionID: "two",
            phase: .thinking,
            label: "Working",
            projectName: "AgenticGlow",
            workingDirectory: "",
            sourceBundleID: nil,
            elapsedSeconds: 12,
            updatedAt: now
        )
        XCTAssertTrue(WorkContextCopy.canReveal(valid))
        XCTAssertFalse(WorkContextCopy.canReveal(missing))
    }
}
