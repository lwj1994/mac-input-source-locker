import XCTest
@testable import MacInputSourceLockerCore

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

    private func makeDefaults() -> UserDefaults {
        let suiteName = "InputLockerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
