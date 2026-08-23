import XCTest
@testable import AgenticGlowCore

final class WorkTitleTests: XCTestCase {
    func testLowercaseHyphenatedSlugBecomesTitleCase() {
        XCTAssertEqual(
            WorkTitle.display("goal-5-5c-execution-04a6d8"),
            "Goal 5 5c Execution"
        )
    }

    func testNormalFolderNamesAreUnchanged() {
        XCTAssertEqual(WorkTitle.display("AgenticGlow"), "AgenticGlow")
        XCTAssertEqual(WorkTitle.display("Caliber Wallet"), "Caliber Wallet")
        XCTAssertEqual(WorkTitle.display("Moodpaper"), "Moodpaper")
    }

    func testAcronymsAndNumbersAreUnchanged() {
        XCTAssertEqual(WorkTitle.display("iOS"), "iOS")
        XCTAssertEqual(WorkTitle.display("API"), "API")
        XCTAssertEqual(WorkTitle.display("v2"), "v2")
    }

    func testPlainLowercaseWordIsUnchanged() {
        XCTAssertEqual(WorkTitle.display("scratch"), "scratch")
    }

    func testHyphenatedSlugWithoutHexSuffix() {
        XCTAssertEqual(WorkTitle.display("horizon-app"), "Horizon App")
    }

    func testGeneratedHexSuffixStaysWhenAmbiguous() {
        XCTAssertEqual(
            WorkTitle.display("goal-5-5c-execution-04a6d8", keepGeneratedSuffix: true),
            "Goal 5 5c Execution 04a6d8"
        )
    }

    func testAllDigitSuffixIsNotTreatedAsGenerated() {
        XCTAssertEqual(WorkTitle.display("release-202401"), "Release 202401")
    }
}

final class WorkDisplayNameTitleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testWorktreeSlugBecomesHumanTitle() {
        let path = "/Volumes/Liquid/2DaMax Development/Caliber Wallet/.claude/worktrees/goal-5-5c-execution-04a6d8"
        let groups = WorkGrouping.groups(from: [session(id: "one", path: path)])
        XCTAssertEqual(groups[0].presentation.displayName, "Goal 5 5c Execution")
        XCTAssertTrue(groups[0].presentation.identity.value.hasSuffix("goal-5-5c-execution-04a6d8"))
        XCTAssertEqual(groups[0].sessions[0].projectName, "goal-5-5c-execution-04a6d8")
    }

    func testAmbiguousWorktreeSuffixesStayVisible() {
        let root = "/Volumes/Liquid/2DaMax Development/Caliber Wallet/.claude/worktrees"
        let groups = WorkGrouping.groups(from: [
            session(id: "a", path: "\(root)/goal-5-5c-execution-04a6d8"),
            session(id: "b", path: "\(root)/goal-5-5c-execution-abcdef")
        ])
        let names = Set(groups.map(\.presentation.displayName))
        XCTAssertEqual(names, [
            "Goal 5 5c Execution 04a6d8",
            "Goal 5 5c Execution abcdef"
        ])
    }

    func testHumanFolderNamesStayExact() {
        let groups = WorkGrouping.groups(from: [
            session(id: "glow", path: "/Volumes/Liquid/2DaMax Development/AgenticGlow"),
            session(id: "caliber", path: "/Volumes/Liquid/2DaMax Development/Caliber Wallet")
        ])
        XCTAssertEqual(
            Set(groups.map(\.presentation.displayName)),
            ["AgenticGlow", "Caliber Wallet"]
        )
    }

    private func session(id: String, path: String) -> SessionSnapshot {
        SessionSnapshot(
            provider: .claude,
            surface: .desktop,
            sessionID: id,
            phase: .thinking,
            label: "Working",
            projectName: URL(fileURLWithPath: path).lastPathComponent,
            workingDirectory: path,
            sourceBundleID: nil,
            elapsedSeconds: 12,
            updatedAt: now
        )
    }
}
