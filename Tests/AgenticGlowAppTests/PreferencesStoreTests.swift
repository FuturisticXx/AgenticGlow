import XCTest
@testable import AgenticGlow

@MainActor
final class PreferencesStoreTests: XCTestCase {
    func testShowTimerPersistsAndUpdatesRunningModel() {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var observedValues: [Bool] = []
        let preferences = PreferencesStore(
            defaults: defaults,
            showTimerDidChange: { observedValues.append($0) }
        )

        preferences.showTimer = true

        XCTAssertTrue(defaults.bool(forKey: "showTimer"))
        XCTAssertEqual(observedValues, [true])
    }

    func testUsageAccessDefaultsOffAndPersistsPerProvider() {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)

        XCTAssertFalse(preferences.codexUsageEnabled)
        XCTAssertFalse(preferences.claudeUsageEnabled)

        preferences.codexUsageEnabled = true

        XCTAssertTrue(defaults.bool(forKey: "codexUsageEnabled"))
        XCTAssertFalse(defaults.bool(forKey: "claudeUsageEnabled"))
    }
}
