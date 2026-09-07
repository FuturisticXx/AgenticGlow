import XCTest
@testable import AgenticGlow

/// The credential-isolation switch is security relevant even though it is
/// test-only, so its condition is pinned rather than left to inspection.
final class TestExecutionEnvironmentTests: XCTestCase {
    func testNormalLaunchDoesNotIsolateCredentials() {
        XCTAssertFalse(
            TestExecutionEnvironment.isRunningTests(
                environment: [:],
                fileExists: { _ in false },
                xctestLoaded: { false }
            )
        )
    }

    /// The exact accident this guards against: a leftover or hand-set
    /// variable naming a configuration file that is not there.
    func testStaleOrInheritedConfigurationPathDoesNotIsolateCredentials() {
        XCTAssertFalse(
            TestExecutionEnvironment.isRunningTests(
                environment: ["XCTestConfigurationFilePath": "/tmp/gone.xctestconfiguration"],
                fileExists: { _ in false },
                xctestLoaded: { false }
            )
        )
    }

    func testEmptyConfigurationPathDoesNotIsolateCredentials() {
        XCTAssertFalse(
            TestExecutionEnvironment.isRunningTests(
                environment: ["XCTestConfigurationFilePath": ""],
                fileExists: { _ in true },
                xctestLoaded: { false }
            )
        )
    }

    func testLiveConfigurationFileIsolatesCredentials() {
        XCTAssertTrue(
            TestExecutionEnvironment.isRunningTests(
                environment: ["XCTestConfigurationFilePath": "/tmp/live.xctestconfiguration"],
                fileExists: { _ in true },
                xctestLoaded: { false }
            )
        )
    }

    /// Covers the window before the runner's variable would be visible:
    /// the XCTest runtime being loaded into this very process.
    func testLoadedXCTestRuntimeIsolatesCredentialsOnItsOwn() {
        XCTAssertTrue(
            TestExecutionEnvironment.isRunningTests(
                environment: [:],
                fileExists: { _ in false },
                xctestLoaded: { true }
            )
        )
    }

    /// And the real process this assertion runs in is, in fact, a test.
    func testCurrentProcessIsDetectedAsATestRun() {
        XCTAssertTrue(TestExecutionEnvironment.isRunningTests())
    }
}
