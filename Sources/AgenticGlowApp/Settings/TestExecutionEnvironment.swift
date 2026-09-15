import Foundation

/// Whether this process is a test run, used only to keep tests off the
/// login Keychain.
///
/// The check exists because app-hosted unit tests launch the real app,
/// and every locally re-signed build is a new code identity, so reading a
/// stored cookie re-prompts for the Keychain password on every run
/// (tasks/lessons.md, 2026-07-10).
///
/// Two independent signals, because neither alone covers the window:
///
/// - `XCTestCase` being loadable proves the XCTest runtime is inside
///   *this* process. It cannot be produced by an environment variable, a
///   stale scheme, or a preview. It is nil early in launch, though: the
///   test bundle is injected after `applicationDidFinishLaunching`.
/// - `XCTestConfigurationFilePath` is set by the test runner before the
///   process starts, which covers that window. It is required to name a
///   file that actually exists, so an inherited or hand-set leftover
///   value from an earlier run does not qualify.
///
/// Getting this wrong is fail-safe rather than credential-exposing. A
/// false positive means the launch finds no stored cookie and Usage
/// Access reads as unconfigured; the in-memory store never reads, writes,
/// or deletes anything in the Keychain, so no credential is exposed and
/// none is lost. A false negative simply restores the previous behavior.
enum TestExecutionEnvironment {
    static func isRunningTests(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        xctestLoaded: () -> Bool = { NSClassFromString("XCTestCase") != nil }
    ) -> Bool {
        if xctestLoaded() { return true }
        guard let path = environment["XCTestConfigurationFilePath"], !path.isEmpty else {
            return false
        }
        return fileExists(path)
    }
}
