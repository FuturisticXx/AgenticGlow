import Foundation
import AgenticGlowCore

/// Sends one message through the macOS Messages app using the same
/// Apple Events mechanism the app already uses to raise a Codex window.
///
/// Every failure resolves to a `.failed` outcome with a readable reason.
/// Nothing here throws, so a denied Automation permission, a signed-out
/// Messages app, or a malformed recipient can never interrupt usage
/// monitoring.
struct MessagesNotifier: MessagesSending {
    /// `NSAppleScript` is synchronous and uncancellable, and it really does
    /// block: sending to Messages from a client macOS has not yet approved
    /// sits on the Automation permission prompt until somebody answers it
    /// (observed blocking indefinitely during development). Without a bound
    /// here, one unanswered prompt would stall every later alert, so the
    /// send always resolves within this window whatever the script is doing.
    static let timeout: TimeInterval = 30

    private let run: @Sendable (String) -> Int?
    private let timeout: TimeInterval

    init(timeout: TimeInterval = MessagesNotifier.timeout) {
        self.timeout = timeout
        run = { source in
            guard let script = NSAppleScript(source: source) else {
                return MessagesSendFailure.applicationNotFound
            }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            guard let error else { return nil }
            return (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue
        }
    }

    init(timeout: TimeInterval = MessagesNotifier.timeout, run: @escaping @Sendable (String) -> Int?) {
        self.timeout = timeout
        self.run = run
    }

    func send(recipient: String, body: String) async -> MessagesSendOutcome {
        guard MessagesScript.isValidRecipient(recipient) else {
            return .failed("No valid Messages recipient is configured.")
        }
        let source = MessagesScript.source(
            recipient: recipient.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body
        )
        let run = self.run
        let timeout = self.timeout
        // Deliberately not a task group: exiting one awaits its children,
        // which a blocked AppleScript call would never let happen. Racing
        // two dispatch blocks onto a single continuation is the only shape
        // that actually returns while the script is still stuck.
        return await withCheckedContinuation { continuation in
            let gate = ResumeGate { continuation.resume(returning: $0) }
            DispatchQueue.global(qos: .utility).async {
                // AppleScript never runs on the main actor.
                let errorNumber = run(source)
                gate.finish(
                    errorNumber.map { .failed(MessagesSendFailure.description(errorNumber: $0)) }
                        ?? .sent
                )
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                gate.finish(.failed(
                    "Messages did not respond. It may be waiting for automation permission."
                ))
            }
        }
    }
}

/// Resumes a continuation exactly once, whichever racer gets there first.
/// Resuming a checked continuation twice is a crash, not a warning.
private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resume: ((MessagesSendOutcome) -> Void)?

    init(resume: @escaping (MessagesSendOutcome) -> Void) {
        self.resume = resume
    }

    func finish(_ outcome: MessagesSendOutcome) {
        let resume = lock.withLock {
            defer { self.resume = nil }
            return self.resume
        }
        resume?(outcome)
    }
}
