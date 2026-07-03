import Foundation
import XCTest
@testable import AgenticGlowCore

final class AllowanceCacheTests: XCTestCase {
    func testCacheStoresOnlyLatestNormalizedValueAndClearsProvider() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileAllowanceCache(directory: directory)
        let first = ProviderAllowance.testValue(provider: .codex, used: 10, fetchedAt: 1)
        let latest = ProviderAllowance.testValue(provider: .codex, used: 20, fetchedAt: 2)

        try cache.save(first)
        try cache.save(latest)

        XCTAssertEqual(try cache.load(.codex), latest)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).count, 1)
        let bytes = try Data(contentsOf: directory.appendingPathComponent("codex.json"))
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).localizedCaseInsensitiveContains("token"))

        try cache.remove(.codex)
        XCTAssertNil(try cache.load(.codex))
    }
}

private extension ProviderAllowance {
    static func testValue(provider: AgentProvider, used: Double, fetchedAt: TimeInterval) -> Self {
        .init(
            provider: provider,
            currentWindowLabel: "5h",
            currentPercentUsed: used,
            currentResetAt: nil,
            weeklyPercentUsed: nil,
            weeklyResetAt: nil,
            fetchedAt: Date(timeIntervalSince1970: fetchedAt)
        )
    }
}
