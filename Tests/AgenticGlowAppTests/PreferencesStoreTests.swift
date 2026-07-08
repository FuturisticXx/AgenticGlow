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

    func testNotificationTogglesDefaultOnAndPersist() {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)

        XCTAssertTrue(preferences.notifyPermission)
        XCTAssertTrue(preferences.notifyQuotaLow)

        preferences.notifyPermission = false

        XCTAssertEqual(defaults.object(forKey: "notifyPermission") as? Bool, false)
        XCTAssertFalse(PreferencesStore(defaults: defaults).notifyPermission)
        XCTAssertTrue(PreferencesStore(defaults: defaults).notifyQuotaLow)
    }

    func testServiceStatusDefaultsOffAndPersists() {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)

        XCTAssertFalse(preferences.serviceStatusEnabled)

        preferences.serviceStatusEnabled = true

        XCTAssertTrue(defaults.bool(forKey: "serviceStatusEnabled"))
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
