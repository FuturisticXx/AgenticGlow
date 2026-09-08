import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class AdditionalUsageDisclosureTests: XCTestCase {
    private func disclosure(on providers: Set<AgentProvider>) -> AdditionalUsageDisclosure {
        AdditionalUsageDisclosure { providers.contains($0) }
    }

    // MARK: - Collapsed

    func testCollapsedShowsOnlyCodexAndClaude() {
        let disclosure = disclosure(on: [.codex, .claude, .cursor])

        XCTAssertEqual(disclosure.visibleProviders(expanded: false), [.codex, .claude])
        XCTAssertFalse(disclosure.visibleProviders(expanded: false).contains(.cursor))
    }

    func testCollapsedOffersTheDownChevronWhenAdditionalUsageExists() {
        XCTAssertTrue(disclosure(on: [.codex, .claude, .cursor]).hasAdditionalUsage)
        XCTAssertEqual(AdditionalUsageDisclosure.symbolName(expanded: false), "chevron.down")
        XCTAssertEqual(
            AdditionalUsageDisclosure.accessibilityLabel(expanded: false),
            "Show additional usage"
        )
    }

    // MARK: - Expanded

    func testExpandedAppendsCursorBelowThePrimaryProviders() {
        let disclosure = disclosure(on: [.codex, .claude, .cursor])

        XCTAssertEqual(disclosure.visibleProviders(expanded: true), [.codex, .claude, .cursor])
    }

    func testExpandedOffersTheUpChevron() {
        XCTAssertEqual(AdditionalUsageDisclosure.symbolName(expanded: true), "chevron.up")
        XCTAssertEqual(
            AdditionalUsageDisclosure.accessibilityLabel(expanded: true),
            "Hide additional usage"
        )
    }

    // MARK: - No additional provider

    func testNoAdditionalProviderMeansNoDisclosureAndNoEmptyArea() {
        let disclosure = disclosure(on: [.codex, .claude])

        XCTAssertFalse(disclosure.hasAdditionalUsage)
        XCTAssertTrue(disclosure.additional.isEmpty)
        XCTAssertEqual(disclosure.visibleProviders(expanded: false), [.codex, .claude])
        // Expanding cannot conjure content, so nothing can open onto blank space.
        XCTAssertEqual(disclosure.visibleProviders(expanded: true), [.codex, .claude])
    }

    func testProviderOffIsExcludedFromItsOwnGroup() {
        let disclosure = disclosure(on: [.claude, .cursor])

        XCTAssertEqual(disclosure.primary, [.claude])
        XCTAssertEqual(disclosure.additional, [.cursor])
    }

    // MARK: - Architecture

    func testCursorIsTheAdditionalProviderAndPrimaryIsCodexThenClaude() {
        XCTAssertEqual(AdditionalUsageDisclosure.additionalProviders, [.cursor])
        XCTAssertEqual(AdditionalUsageDisclosure.primaryProviderOrder, [.codex, .claude])
    }

    /// The split is derived from `AgentProvider.allCases`, so a provider added
    /// later lands in the primary view only if it is deliberately left out of
    /// `additionalProviders`.
    func testPrimaryAndAdditionalTogetherCoverEveryProvider() {
        let covered = AdditionalUsageDisclosure.primaryProviderOrder
            + AdditionalUsageDisclosure.additionalProviders
        XCTAssertEqual(Set(covered), Set(AgentProvider.allCases))
    }
}
