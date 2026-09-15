import Foundation
import Security

protocol SessionCredentialStoring: Sendable {
    func load() throws -> String?
    func save(_ credential: String) throws
    func delete() throws
}

protocol KeychainAccessing: Sendable {
    func read(service: String, account: String) throws -> Data?
    func save(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String) throws
}

struct SessionCredentialError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// A single provider's usage-access credential, held only in the login
/// Keychain. Never written to preferences, the widget snapshot, or
/// diagnostics, and never read back out of the provider's own app or any
/// browser: the user pastes it in Usage Access or there is none.
final class SessionCredentialStore: SessionCredentialStoring, @unchecked Sendable {
    static func claude(keychain: any KeychainAccessing = SystemKeychainAccess()) -> SessionCredentialStore {
        SessionCredentialStore(
            service: "com.twodamax.agenticglow.claude-session.v1",
            account: "claude.ai",
            providerName: "Claude",
            emptyMessage: "Paste the full Claude session cookie.",
            keychain: keychain
        )
    }

    /// A separate Keychain service from Claude's, so one provider's
    /// credential can never be read, overwritten, or deleted through the
    /// other's Usage Access toggle.
    static func cursor(keychain: any KeychainAccessing = SystemKeychainAccess()) -> SessionCredentialStore {
        SessionCredentialStore(
            service: "com.twodamax.agenticglow.cursor-session.v1",
            account: "cursor.com",
            providerName: "Cursor",
            emptyMessage: "Paste the full Cursor session cookie.",
            keychain: keychain
        )
    }

    private let service: String
    private let account: String
    private let providerName: String
    private let emptyMessage: String
    private let keychain: any KeychainAccessing

    init(
        service: String,
        account: String,
        providerName: String,
        emptyMessage: String,
        keychain: any KeychainAccessing = SystemKeychainAccess()
    ) {
        self.service = service
        self.account = account
        self.providerName = providerName
        self.emptyMessage = emptyMessage
        self.keychain = keychain
    }

    func load() throws -> String? {
        guard let data = try keychain.read(
            service: service,
            account: account
        ) else { return nil }
        guard let value = String(data: data, encoding: .utf8) else {
            throw SessionCredentialError(message: "\(providerName) credential could not be read.")
        }
        return value
    }

    func save(_ credential: String) throws {
        let value = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw SessionCredentialError(message: emptyMessage)
        }
        try keychain.save(
            Data(value.utf8),
            service: service,
            account: account
        )
    }

    func delete() throws {
        try keychain.delete(service: service, account: account)
    }
}

final class InMemorySessionCredentialStore: SessionCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var credential: String?

    func load() throws -> String? { lock.withLock { credential } }
    func save(_ credential: String) throws { lock.withLock { self.credential = credential } }
    func delete() throws { lock.withLock { credential = nil } }
}

final class SystemKeychainAccess: KeychainAccessing, @unchecked Sendable {
    func read(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw keychainError(status)
        }
        return data
    }

    func save(_ data: Data, service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw keychainError(updateStatus)
        }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw keychainError(addStatus) }
    }

    func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainError(_ status: OSStatus) -> SessionCredentialError {
        let detail = SecCopyErrorMessageString(status, nil) as String?
        return SessionCredentialError(
            message: detail.map { "Credential could not be saved: \($0)" }
                ?? "Credential could not be saved."
        )
    }
}
