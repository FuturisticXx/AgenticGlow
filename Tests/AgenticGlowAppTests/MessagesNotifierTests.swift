import Foundation
import XCTest
@testable import AgenticGlow
@testable import AgenticGlowCore

final class MessagesNotifierTests: XCTestCase {
    func testSuccessfulSendReportsSent() async {
        let notifier = MessagesNotifier(timeout: 5) { _ in nil }
        let outcome = await notifier.send(recipient: "+15550000000", body: "hello")
        XCTAssertEqual(outcome, .sent)
    }

    func testDeniedAutomationIsReportedActionably() async {
        let notifier = MessagesNotifier(timeout: 5) { _ in MessagesSendFailure.notPermitted }
        let outcome = await notifier.send(recipient: "+15550000000", body: "hello")
        guard case let .failed(reason) = outcome else {
            return XCTFail("expected a failure outcome")
        }
        XCTAssertTrue(reason.contains("Automation permission denied"))
    }

    /// The real failure mode found during live testing: an unanswered
    /// Automation prompt leaves NSAppleScript blocked forever. The send must
    /// still resolve, or it would stall every later alert on the delivery
    /// queue, including native notifications.
    func testBlockedScriptStillResolvesWithinTheTimeout() async {
        let released = DispatchSemaphore(value: 0)
        let notifier = MessagesNotifier(timeout: 0.2) { _ in
            released.wait()
            return nil
        }

        let started = Date()
        let outcome = await notifier.send(recipient: "+15550000000", body: "hello")
        let elapsed = Date().timeIntervalSince(started)

        guard case let .failed(reason) = outcome else {
            return XCTFail("expected a timeout failure")
        }
        XCTAssertTrue(reason.contains("did not respond"))
        XCTAssertLessThan(elapsed, 5)
        // Let the stuck worker finish so it cannot outlive the test.
        released.signal()
    }

    func testTimeoutAfterCompletionDoesNotResumeTwice() async {
        // A late timeout firing after a real result must be a no-op rather
        // than a double resume, which would crash the process.
        let notifier = MessagesNotifier(timeout: 0.1) { _ in nil }
        for _ in 0 ..< 20 {
            _ = await notifier.send(recipient: "+15550000000", body: "hello")
        }
        try? await Task.sleep(for: .milliseconds(300))
    }

    func testInvalidRecipientNeverRunsTheScript() async {
        let ran = Ran()
        let notifier = MessagesNotifier(timeout: 5) { _ in
            ran.mark()
            return nil
        }

        let outcome = await notifier.send(recipient: "bad\nrecipient", body: "hello")

        guard case let .failed(reason) = outcome else {
            return XCTFail("expected a failure outcome")
        }
        XCTAssertTrue(reason.contains("No valid Messages recipient"))
        XCTAssertFalse(ran.didRun)
    }

    func testRecipientIsTrimmedBeforeReachingTheScript() async {
        let captured = Captured()
        let notifier = MessagesNotifier(timeout: 5) { source in
            captured.store(source)
            return nil
        }

        _ = await notifier.send(recipient: "  +15550000000  ", body: "hello")

        XCTAssertTrue(captured.value?.contains(#"participant "+15550000000""# ) == true)
    }
}

private final class Ran: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var didRun: Bool { lock.withLock { value } }
    func mark() { lock.withLock { value = true } }
}

private final class Captured: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: String?
    var value: String? { lock.withLock { storage } }
    func store(_ source: String) { lock.withLock { storage = source } }
}
