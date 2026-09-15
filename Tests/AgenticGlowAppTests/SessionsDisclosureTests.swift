import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

/// The popover has two independent disclosures around a permanent
/// Codex/Claude anchor: Sessions above, additional usage providers below.
/// These cover the four combinations and the independence between them.
final class SessionsDisclosureTests: XCTestCase {
    private func allowance(on providers: Set<AgentProvider>) -> AdditionalUsageDisclosure {
        AdditionalUsageDisclosure { providers.contains($0) }
    }

    private let everyProvider: Set<AgentProvider> = [.codex, .claude, .cursor]

    // MARK: - The four combinations

    func testCompactestHidesSessionsAndCursorAndKeepsCodexAndClaude() {
        let sessionsExpanded = false
        let usageExpanded = false
        let providers = allowance(on: everyProvider).visibleProviders(expanded: usageExpanded)

        XCTAssertFalse(SessionsDisclosure.showsSessions(expanded: sessionsExpanded))
        XCTAssertEqual(providers, [.codex, .claude])
        XCTAssertFalse(providers.contains(.cursor))
    }

    func testSessionsOnlyShowsSessionsAndKeepsCursorHidden() {
        let sessionsExpanded = true
        let usageExpanded = false
        let providers = allowance(on: everyProvider).visibleProviders(expanded: usageExpanded)

        XCTAssertTrue(SessionsDisclosure.showsSessions(expanded: sessionsExpanded))
        XCTAssertEqual(providers, [.codex, .claude])
    }

    func testAdditionalUsageOnlyShowsCursorAndKeepsSessionsHidden() {
        let sessionsExpanded = false
        let usageExpanded = true
        let providers = allowance(on: everyProvider).visibleProviders(expanded: usageExpanded)

        XCTAssertFalse(SessionsDisclosure.showsSessions(expanded: sessionsExpanded))
        XCTAssertEqual(providers, [.codex, .claude, .cursor])
    }

    func testEverythingExpandedShowsSessionsAndCursor() {
        let sessionsExpanded = true
        let usageExpanded = true
        let providers = allowance(on: everyProvider).visibleProviders(expanded: usageExpanded)

        XCTAssertTrue(SessionsDisclosure.showsSessions(expanded: sessionsExpanded))
        XCTAssertEqual(providers, [.codex, .claude, .cursor])
    }

    /// Codex and Claude are the anchor: they are present in all four states.
    func testCodexAndClaudeAreVisibleInEveryCombination() {
        for sessionsExpanded in [false, true] {
            for usageExpanded in [false, true] {
                let providers = allowance(on: everyProvider)
                    .visibleProviders(expanded: usageExpanded)
                XCTAssertTrue(providers.contains(.codex))
                XCTAssertTrue(providers.contains(.claude))
                XCTAssertEqual(
                    SessionsDisclosure.showsSessions(expanded: sessionsExpanded),
                    sessionsExpanded
                )
            }
        }
    }

    // MARK: - Independence

    /// The two disclosures are separate types over separate view state. Neither
    /// reads the other, so sessions visibility cannot depend on the allowance
    /// disclosure and the provider list cannot depend on the sessions one.
    func testNeitherDisclosureMutatesOrObservesTheOther() {
        let disclosure = allowance(on: everyProvider)

        for sessionsExpanded in [false, true] {
            XCTAssertEqual(disclosure.visibleProviders(expanded: false), [.codex, .claude])
            XCTAssertEqual(
                disclosure.visibleProviders(expanded: true),
                [.codex, .claude, .cursor]
            )
            XCTAssertEqual(
                SessionsDisclosure.showsSessions(expanded: sessionsExpanded),
                sessionsExpanded
            )
        }
    }

    // MARK: - Default state

    func testANewlyPresentedPopoverStartsWithSessionsVisible() {
        XCTAssertTrue(SessionsDisclosure.defaultExpanded)
        XCTAssertTrue(SessionsDisclosure.showsSessions(expanded: SessionsDisclosure.defaultExpanded))
    }

    /// Sessions open by default, additional usage stays parked. The two
    /// defaults are set independently of each other.
    func testTheDefaultViewIsSessionsPlusCodexAndClaude() {
        let providers = allowance(on: everyProvider).visibleProviders(expanded: false)

        XCTAssertTrue(SessionsDisclosure.showsSessions(expanded: SessionsDisclosure.defaultExpanded))
        XCTAssertEqual(providers, [.codex, .claude])
    }

    // MARK: - Control

    func testChevronDirectionMatchesTheAdditionalUsageControl() {
        XCTAssertEqual(SessionsDisclosure.symbolName(expanded: false), "chevron.down")
        XCTAssertEqual(SessionsDisclosure.symbolName(expanded: true), "chevron.up")
        XCTAssertEqual(
            SessionsDisclosure.symbolName(expanded: false),
            AdditionalUsageDisclosure.symbolName(expanded: false)
        )
        XCTAssertEqual(
            SessionsDisclosure.symbolName(expanded: true),
            AdditionalUsageDisclosure.symbolName(expanded: true)
        )
    }

    func testAccessibilityLabelsDescribeTheActionWithoutAVisibleLabel() {
        XCTAssertEqual(SessionsDisclosure.accessibilityLabel(expanded: false), "Show sessions")
        XCTAssertEqual(SessionsDisclosure.accessibilityLabel(expanded: true), "Hide sessions")
    }
}
