import XCTest
@testable import KlarityCore

final class DiagnosticLoggerTests: XCTestCase {
    func testLoggerWritesOnlyApprovedMetadataWhenEnabled() throws {
        let url = temporaryDirectory().appendingPathComponent("klarity.log")
        let logger = DiagnosticLogger(enabled: true, url: url)
        logger.record(
            provider: .codex,
            event: .preToolUse,
            sessionID: "session",
            result: "normalized",
            rawPayload: "SECRET_COMMAND"
        )
        let text = try String(contentsOf: url)
        XCTAssertTrue(text.contains("normalized"))
        XCTAssertFalse(text.contains("SECRET_COMMAND"))
    }
}
