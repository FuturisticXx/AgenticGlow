import Foundation
import Security

protocol ClaudeSessionCredentialStoring: Sendable {
    func load() throws -> String?
    func save(_ credential: String) throws
    func delete() throws
}

protocol KeychainAccessing: Sendable {
    func read(service: String, account: String) throws -> Data?
    func save(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String) throws
}

struct ClaudeCredentialError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class ClaudeSessionCredentialStore: ClaudeSessionCredentialStoring, @unchecked Sendable {
    private static let service = "com.twodamax.agenticglow.claude-session.v1"
    private static let account = "claude.ai"
    private let keychain: any KeychainAccessing

    init(keychain: any KeychainAccessing = SystemKeychainAccess()) {
        self.keychain = keychain
    }

    func load() throws -> String? {
        guard let data = try keychain.read(
            service: Self.service,
            account: Self.account
        ) else { return nil }
        guard let value = String(data: data, encoding: .utf8) else {
            throw ClaudeCredentialError(message: "Claude credential could not be read.")
        }
        return value
    }

    func save(_ credential: String) throws {
        let value = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw ClaudeCredentialError(message: "Paste the full Claude session cookie.")
        }
        try keychain.save(
            Data(value.utf8),
            service: Self.service,
            account: Self.account
        )
    }

    func delete() throws {
        try keychain.delete(service: Self.service, account: Self.account)
    }
}

final class InMemoryClaudeSessionCredentialStore: ClaudeSessionCredentialStoring, @unchecked Sendable {
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

    private func keychainError(_ status: OSStatus) -> ClaudeCredentialError {
        let detail = SecCopyErrorMessageString(status, nil) as String?
        return ClaudeCredentialError(
            message: detail.map { "Claude credential could not be saved: \($0)" }
                ?? "Claude credential could not be saved."
        )
    }
}
