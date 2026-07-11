import XCTest
import Observation
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

    func testGlassClarityDefaultsToCurrentAppearanceAndPersists() {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)

        XCTAssertEqual(preferences.glassClarity, 0)

        preferences.glassClarity = 0.72

        XCTAssertEqual(defaults.double(forKey: "glassClarity"), 0.72)
        XCTAssertEqual(PreferencesStore(defaults: defaults).glassClarity, 0.72)
    }

    func testGlassClarityClampsToSupportedRangeBeforePersisting() {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)

        preferences.glassClarity = 1.4

        XCTAssertEqual(preferences.glassClarity, 1)
        XCTAssertEqual(defaults.double(forKey: "glassClarity"), 1)

        preferences.glassClarity = -0.2

        XCTAssertEqual(preferences.glassClarity, 0)
        XCTAssertEqual(defaults.double(forKey: "glassClarity"), 0)
    }

    func testGlassClarityChangeInvalidatesObserversForLivePreview() async {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)
        let changed = expectation(description: "glass clarity observation changed")

        withObservationTracking {
            _ = preferences.glassClarity
        } onChange: {
            changed.fulfill()
        }

        preferences.glassClarity = 0.5

        await fulfillment(of: [changed], timeout: 0.2)
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
