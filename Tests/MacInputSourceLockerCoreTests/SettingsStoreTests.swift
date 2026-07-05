import XCTest
import MacInputSourceLockerCore

final class SettingsStoreTests: XCTestCase {
    func testLockDefaultsToEnabled() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.isLockEnabled)
    }

    func testTargetInputSourceIDTrimsBlankValues() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)

        store.targetInputSourceID = "  com.apple.keylayout.ABC  "
        XCTAssertEqual(store.targetInputSourceID, "com.apple.keylayout.ABC")

        store.targetInputSourceID = "   "
        XCTAssertNil(store.targetInputSourceID)
    }

    func testAppInputSourceRulesCanBeSavedUpdatedAndRemoved() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)

        store.setAppInputSourceRule(
            bundleIdentifier: "  com.apple.TextEdit  ",
            appName: "  TextEdit  ",
            inputSourceID: "  com.apple.keylayout.ABC  "
        )

        XCTAssertEqual(store.appInputSourceRules.count, 1)
        XCTAssertEqual(store.appInputSourceRule(for: "com.apple.TextEdit")?.appName, "TextEdit")
        XCTAssertEqual(store.appInputSourceRule(for: "com.apple.TextEdit")?.inputSourceID, "com.apple.keylayout.ABC")

        store.setAppInputSourceRule(
            bundleIdentifier: "com.apple.TextEdit",
            appName: "TextEdit",
            inputSourceID: "com.apple.inputmethod.SCIM.ITABC"
        )

        XCTAssertEqual(store.appInputSourceRules.count, 1)
        XCTAssertEqual(store.appInputSourceRule(for: "com.apple.TextEdit")?.inputSourceID, "com.apple.inputmethod.SCIM.ITABC")

        store.removeAppInputSourceRule(for: "com.apple.TextEdit")
        XCTAssertTrue(store.appInputSourceRules.isEmpty)
    }

    func testInvalidAppInputSourceRulesAreIgnored() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)

        store.setAppInputSourceRule(bundleIdentifier: " ", appName: "TextEdit", inputSourceID: "com.apple.keylayout.ABC")
        store.setAppInputSourceRule(bundleIdentifier: "com.apple.TextEdit", appName: "TextEdit", inputSourceID: " ")

        XCTAssertTrue(store.appInputSourceRules.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "InputLockerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
