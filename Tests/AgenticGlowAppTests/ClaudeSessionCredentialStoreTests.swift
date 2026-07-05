import Foundation
import XCTest
@testable import AgenticGlow

final class ClaudeSessionCredentialStoreTests: XCTestCase {
    func testCredentialIsAddedLoadedUpdatedAndDeletedThroughKeychain() throws {
        let keychain = RecordingKeychainAccess()
        let store = ClaudeSessionCredentialStore(keychain: keychain)

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
}

private final class RecordingKeychainAccess: KeychainAccessing, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private(set) var savedService: String?
    private(set) var savedAccount: String?

    func read(service: String, account: String) throws -> Data? {
        lock.withLock { data }
    }

    func save(_ data: Data, service: String, account: String) throws {
        lock.withLock {
            self.data = data
            savedService = service
            savedAccount = account
        }
    }

    func delete(service: String, account: String) throws {
        lock.withLock { data = nil }
    }
}
