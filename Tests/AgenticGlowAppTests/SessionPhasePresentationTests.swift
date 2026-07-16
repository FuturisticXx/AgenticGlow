import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class SessionPhasePresentationTests: XCTestCase {
    func testRowSymbolNamesMatchExistingRowIconography() {
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .permission, in: .row), "exclamationmark.circle.fill")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .completed, in: .row), "checkmark.circle.fill")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .disconnected, in: .row), "bolt.slash.circle")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .idle, in: .row), "circle")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .thinking, in: .row), "sparkle")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, in: .row), "sparkle")
    }

    func testMenuBarSymbolNamesMatchExistingStatusIconography() {
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .permission, in: .menuBar), "exclamationmark.circle.fill")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .completed, in: .menuBar), "checkmark.circle.fill")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .disconnected, in: .menuBar), "bolt.slash.circle")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .idle, in: .menuBar), "circle.hexagongrid")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .thinking, in: .menuBar), "circle.hexagongrid")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, in: .menuBar), "circle.hexagongrid")
    }

    func testNonProviderTintedColorsAreSharedAcrossBothSurfaces() {
        XCTAssertEqual(SessionPhasePresentation.nsColor(for: .permission), .systemYellow)
        XCTAssertEqual(SessionPhasePresentation.nsColor(for: .completed), .systemGreen)
        XCTAssertEqual(SessionPhasePresentation.nsColor(for: .disconnected), .secondaryLabelColor)
        XCTAssertEqual(SessionPhasePresentation.nsColor(for: .idle), .labelColor)
    }

    func testEveryPhaseHasExactlyOneEntryPerContext() {
        for phase in [SessionPhase.idle, .thinking, .usingTool, .permission, .completed, .disconnected, .failed] {
            XCTAssertFalse(SessionPhasePresentation.symbolName(for: phase, in: .row).isEmpty)
            XCTAssertFalse(SessionPhasePresentation.symbolName(for: phase, in: .menuBar).isEmpty)
        }
    }

    func testRowUsesToolCategoryIconWhileUsingATool() {
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, toolCategory: .read, in: .row), "doc.text")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, toolCategory: .edit, in: .row), "pencil")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, toolCategory: .search, in: .row), "magnifyingglass")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, toolCategory: .browse, in: .row), "globe")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, toolCategory: .command, in: .row), "terminal")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, toolCategory: .delegate, in: .row), "arrow.triangle.branch")
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, toolCategory: .other, in: .row), "sparkle")
    }

    func testRowFallsBackToSparkleWhenUsingToolHasNoCategory() {
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .usingTool, in: .row), "sparkle")
    }

    func testRowIgnoresToolCategoryWhileThinking() {
        XCTAssertEqual(SessionPhasePresentation.symbolName(for: .thinking, toolCategory: .edit, in: .row), "sparkle")
    }

    func testMenuBarIgnoresToolCategory() {
        XCTAssertEqual(
            SessionPhasePresentation.symbolName(for: .usingTool, toolCategory: .edit, in: .menuBar),
            "circle.hexagongrid"
        )
    }
}
