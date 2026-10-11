import Foundation

/// Builds the AppleScript used to send one message through the macOS
/// Messages app, and validates the pieces that go into it.
///
/// Both the recipient and the body are interpolated into AppleScript string
/// literals, so escaping is a security boundary, not a formatting detail:
/// an unescaped quote in either would let the value execute as script. A
/// newline cannot be escaped inside an AppleScript literal at all, which is
/// why `isValidRecipient` rejects those outright instead of trying.
public enum MessagesScript {
    public static func source(recipient: String, body: String) -> String {
        """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(escape(recipient))" of targetService
            send "\(escape(body))" to targetBuddy
        end tell
        """
    }

    public static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// A recipient is whatever Messages itself accepts: a phone number or
    /// an Apple Account email address. AgenticGlow does not try to parse
    /// either, only to rule out values that cannot be safely quoted.
    public static func isValidRecipient(_ recipient: String) -> Bool {
        let trimmed = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.rangeOfCharacter(from: .newlines) == nil
            && trimmed.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}

public enum MessagesSendOutcome: Equatable, Sendable {
    case sent
    case failed(String)
}

public protocol MessagesSending: Sendable {
    func send(recipient: String, body: String) async -> MessagesSendOutcome
}

/// Maps AppleScript failures onto something a user can act on. Kept pure so
/// the mapping is testable without provoking a real permission denial.
public enum MessagesSendFailure {
    /// errAEEventNotPermitted: the user denied or has not yet granted
    /// Automation access for Messages.
    public static let notPermitted = -1743
    /// procNotFound: Messages could not be reached.
    public static let applicationNotFound = -600

    public static func description(errorNumber: Int?) -> String {
        switch errorNumber {
        case notPermitted?:
            "Automation permission denied. Allow AgenticGlow to control Messages in System Settings, Privacy & Security, Automation."
        case applicationNotFound?:
            "Messages could not be reached. Open Messages and sign in to iMessage."
        default:
            "Messages did not accept the message."
        }
    }
}
