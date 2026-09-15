import Foundation
import XCTest
@testable import AgenticGlow

final class SessionCredentialStoreTests: XCTestCase {
    func testClaudeCredentialIsAddedLoadedUpdatedAndDeletedThroughKeychain() throws {
        let keychain = RecordingKeychainAccess()
        let store = SessionCredentialStore.claude(keychain: keychain)

        XCTAssertNil(try store.load())

        try store.save("first-cookie")
        XCTAssertEqual(try store.load(), "first-cookie")
        XCTAssertEqual(keychain.savedService, "com.twodamax.agenticglow.claude-session.v1")
        XCTAssertEqual(keychain.savedAccount, "claude.ai")

        try store.save("updated-cookie")
        XCTAssertEqual(try store.load(), "updated-cookie")

        try store.delete()
        XCTAssertNil(try store.load())
    }

    func testCursorCredentialIsAddedLoadedUpdatedAndDeletedThroughKeychain() throws {
        let keychain = RecordingKeychainAccess()
        let store = SessionCredentialStore.cursor(keychain: keychain)

        XCTAssertNil(try store.load())

        try store.save("cursor-cookie")
        XCTAssertEqual(try store.load(), "cursor-cookie")
        XCTAssertEqual(keychain.savedService, "com.twodamax.agenticglow.cursor-session.v1")
        XCTAssertEqual(keychain.savedAccount, "cursor.com")

        try store.save("replacement-cookie")
        XCTAssertEqual(try store.load(), "replacement-cookie")

        try store.delete()
        XCTAssertNil(try store.load())
    }

    /// Turning one provider's usage access off must not disturb the
    /// other's stored credential.
    func testProviderCredentialsAreStoredIndependently() throws {
        let keychain = RecordingKeychainAccess()
        let claude = SessionCredentialStore.claude(keychain: keychain)
        let cursor = SessionCredentialStore.cursor(keychain: keychain)

        try claude.save("claude-cookie")
        try cursor.save("cursor-cookie")

        XCTAssertEqual(try claude.load(), "claude-cookie")
        XCTAssertEqual(try cursor.load(), "cursor-cookie")

        try cursor.delete()

        XCTAssertNil(try cursor.load())
        XCTAssertEqual(try claude.load(), "claude-cookie")
    }

    func testBlankCursorCredentialIsRejected() {
        let store = SessionCredentialStore.cursor(keychain: RecordingKeychainAccess())

        XCTAssertThrowsError(try store.save("   ")) { error in
            XCTAssertEqual(
                (error as? SessionCredentialError)?.message,
                "Paste the full Cursor session cookie."
            )
        }
    }
}

private final class RecordingKeychainAccess: KeychainAccessing, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]
    private(set) var savedService: String?
    private(set) var savedAccount: String?

    func read(service: String, account: String) throws -> Data? {
        lock.withLock { items["\(service)|\(account)"] }
    }

    func save(_ data: Data, service: String, account: String) throws {
        lock.withLock {
            items["\(service)|\(account)"] = data
            savedService = service
            savedAccount = account
        }
    }

    func delete(service: String, account: String) throws {
        _ = lock.withLock { items.removeValue(forKey: "\(service)|\(account)") }
    }
}
