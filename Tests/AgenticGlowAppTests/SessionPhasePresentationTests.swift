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
        for phase in [SessionPhase.idle, .thinking, .usingTool, .permission, .completed, .disconnected] {
            XCTAssertFalse(SessionPhasePresentation.symbolName(for: phase, in: .row).isEmpty)
            XCTAssertFalse(SessionPhasePresentation.symbolName(for: phase, in: .menuBar).isEmpty)
        }
    }
}
