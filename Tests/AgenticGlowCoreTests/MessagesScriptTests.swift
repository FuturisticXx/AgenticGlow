import Foundation
import XCTest
@testable import AgenticGlowCore

final class MessagesScriptTests: XCTestCase {
    func testQuotesAndBackslashesAreEscapedInBothFields() {
        // Both fields land inside AppleScript string literals, so an
        // unescaped quote would let the value execute as script.
        let source = MessagesScript.source(
            recipient: #"a"b\c"#,
            body: #"say "hi""#
        )
        XCTAssertTrue(source.contains(#"participant "a\"b\\c""#))
        XCTAssertTrue(source.contains(#"send "say \"hi\"""#))
    }

    func testScriptTargetsMessagesOverIMessage() {
        let source = MessagesScript.source(recipient: "+15550000000", body: "hello")
        XCTAssertTrue(source.contains(#"tell application "Messages""#))
        XCTAssertTrue(source.contains("service type = iMessage"))
        XCTAssertFalse(source.contains("System Events"))
    }

    func testRecipientValidation() {
        XCTAssertTrue(MessagesScript.isValidRecipient("+15550000000"))
        XCTAssertTrue(MessagesScript.isValidRecipient("someone@example.com"))
        XCTAssertTrue(MessagesScript.isValidRecipient("  +15550000000  "))
        XCTAssertFalse(MessagesScript.isValidRecipient(""))
        XCTAssertFalse(MessagesScript.isValidRecipient("   "))
        // A newline cannot be escaped inside an AppleScript literal, so it
        // is rejected rather than smuggled into the script.
        XCTAssertFalse(MessagesScript.isValidRecipient("a\nend tell"))
        XCTAssertFalse(MessagesScript.isValidRecipient("a\rb"))
        XCTAssertFalse(MessagesScript.isValidRecipient("a\u{0}b"))
    }

    func testFailureDescriptionsAreActionable() {
        XCTAssertTrue(
            MessagesSendFailure.description(errorNumber: MessagesSendFailure.notPermitted)
                .contains("Automation permission denied")
        )
        XCTAssertTrue(
            MessagesSendFailure.description(errorNumber: MessagesSendFailure.applicationNotFound)
                .contains("Messages could not be reached")
        )
        XCTAssertFalse(MessagesSendFailure.description(errorNumber: nil).isEmpty)
    }

    func testAlertCopy() {
        let alert = UsageResetAlert(event: UsageResetEvent(
            key: UsageWindowKey(provider: .codex, windowLabel: UsageWindowKey.weeklyLabel),
            percentLeft: 100,
            detectedAt: Date(timeIntervalSince1970: 1_783_099_000)
        ))
        XCTAssertEqual(alert.title, "Codex Usage Reset")
        XCTAssertEqual(alert.body, "Codex weekly usage has reset and is available again.")
        XCTAssertEqual(
            alert.messageText,
            "AgenticGlow: Codex weekly usage has reset and is available again."
        )
        XCTAssertEqual(alert.notificationID, "usageReset.codex.week")
        XCTAssertFalse(alert.isTest)
    }

    func testTestAlertCopyIsObviouslyATest() {
        let alert = UsageResetAlert(
            key: UsageWindowKey(provider: .claude, windowLabel: UsageWindowKey.weeklyLabel),
            isTest: true
        )
        XCTAssertTrue(alert.isTest)
        XCTAssertTrue(alert.title.contains("test"))
        XCTAssertTrue(alert.messageText.hasPrefix("AgenticGlow test alert"))
    }
}
