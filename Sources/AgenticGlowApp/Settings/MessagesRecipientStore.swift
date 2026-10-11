import Foundation
import AgenticGlowCore

protocol MessagesRecipientStoring: Sendable {
    func load() throws -> String?
    func save(_ recipient: String) throws
    func delete() throws
}

struct MessagesRecipientError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// A phone number or Apple Account address is personal contact data, so it
/// lives in the Keychain beside the Claude cookie rather than in a settings
/// plist that any process running as the user can read.
final class MessagesRecipientStore: MessagesRecipientStoring, @unchecked Sendable {
    private static let service = "com.twodamax.agenticglow.messages-recipient.v1"
    private static let account = "messages"
    private let keychain: any KeychainAccessing

    init(keychain: any KeychainAccessing = SystemKeychainAccess()) {
        self.keychain = keychain
    }

    func load() throws -> String? {
        do {
            guard let data = try keychain.read(
                service: Self.service,
                account: Self.account
            ) else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            throw MessagesRecipientError(message: "The Messages recipient could not be read.")
        }
    }

    func save(_ recipient: String) throws {
        let value = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MessagesScript.isValidRecipient(value) else {
            throw MessagesRecipientError(
                message: "Enter the phone number or Apple Account address you message from this Mac."
            )
        }
        do {
            try keychain.save(Data(value.utf8), service: Self.service, account: Self.account)
        } catch {
            throw MessagesRecipientError(message: "The Messages recipient could not be saved.")
        }
    }

    func delete() throws {
        do {
            try keychain.delete(service: Self.service, account: Self.account)
        } catch {
            throw MessagesRecipientError(message: "The Messages recipient could not be removed.")
        }
    }
}

final class InMemoryMessagesRecipientStore: MessagesRecipientStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var recipient: String?

    init(recipient: String? = nil) {
        self.recipient = recipient
    }

    func load() throws -> String? { lock.withLock { recipient } }
    func save(_ recipient: String) throws { lock.withLock { self.recipient = recipient } }
    func delete() throws { lock.withLock { recipient = nil } }
}
