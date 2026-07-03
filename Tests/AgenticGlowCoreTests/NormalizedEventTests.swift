import XCTest
@testable import AgenticGlowCore

final class NormalizedEventTests: XCTestCase {
    func testRoundTripUsesSecondsSince1970() throws {
        let event = NormalizedEvent.fixture()
        let data = try JSONEncoder.agenticglow.encode(event)
        let decoded = try JSONDecoder.agenticglow.decode(NormalizedEvent.self, from: data)
        XCTAssertEqual(decoded, event)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("prompt"))
    }

    func testValidationRejectsUnsupportedSchema() {
        var event = NormalizedEvent.fixture()
        event.schemaVersion = 99
        XCTAssertThrowsError(try event.validate()) { error in
            XCTAssertEqual(error as? EventValidationError, .unsupportedSchema(99))
        }
    }

    func testValidationRejectsUnsafeSessionIdentifier() {
        var event = NormalizedEvent.fixture()
        event.sessionID = "../escape"
        XCTAssertThrowsError(try event.validate())
    }
}

private extension NormalizedEvent {
    static func fixture() -> Self {
        .init(
            schemaVersion: 1,
            provider: .codex,
            surface: .cli,
            sessionID: "session-1",
            turnID: "turn-1",
            phase: .thinking,
            label: "Thinking",
            toolCategory: nil,
            projectName: "AgenticGlow",
            workingDirectory: "/tmp/AgenticGlow",
            sourceBundleID: "com.apple.Terminal",
            sourceProcessID: 123,
            sourceProcessStartedAt: Date(timeIntervalSince1970: 100),
            turnStartedAt: Date(timeIntervalSince1970: 110),
            updatedAt: Date(timeIntervalSince1970: 120)
        )
    }
}
