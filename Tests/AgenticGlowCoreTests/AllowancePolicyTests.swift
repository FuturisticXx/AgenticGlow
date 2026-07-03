import Foundation
import XCTest
@testable import AgenticGlowCore

final class AllowancePolicyTests: XCTestCase {
    func testRefreshCadenceMatchesApprovedSpecification() {
        XCTAssertEqual(AllowanceRefreshPolicy.turnCompletionDebounce, 4)
        XCTAssertEqual(AllowanceRefreshPolicy.workingInterval, 60)
        XCTAssertEqual(AllowanceRefreshPolicy.popoverMaximumAge, 15)
        XCTAssertEqual(AllowanceRefreshPolicy.idleInterval, 300)
    }

    func testClaudeAdapterStopsWithoutCredentialOrNetworkAccess() async {
        let adapter = UnsupportedClaudeAllowanceAdapter()

        do {
            _ = try await adapter.fetch()
            XCTFail("Expected unsupported provider")
        } catch let error as AllowanceAdapterError {
            XCTAssertEqual(error, .unsupported("Anthropic does not document a programmatic subscription-allowance endpoint."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
