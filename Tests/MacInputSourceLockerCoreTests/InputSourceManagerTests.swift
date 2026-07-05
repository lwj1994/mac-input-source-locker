import XCTest
import MacInputSourceLockerCore

final class InputSourceManagerTests: XCTestCase {
    func testInputSourceClassifiesKeyboardCategory() {
        let source = InputSource(
            id: "com.apple.keylayout.ABC",
            localizedName: "ABC",
            category: "TISCategoryKeyboardInputSource",
            isEnabled: true,
            isSelectCapable: true
        )

        XCTAssertTrue(source.isKeyboardInputSource)
    }

    func testInputSourceRejectsPaletteCategory() {
        let source = InputSource(
            id: "com.apple.CharacterPaletteIM",
            localizedName: "Emoji & Symbols",
            category: "TISCategoryPaletteInputSource",
            isEnabled: true,
            isSelectCapable: true
        )

        XCTAssertFalse(source.isKeyboardInputSource)
    }

    func testCanReadCurrentInputSource() {
        let manager = InputSourceManager()

        XCTAssertNotNil(manager.currentInputSource()?.id)
    }

    func testCanListSelectableInputSources() {
        let manager = InputSourceManager()

        XCTAssertFalse(manager.selectableInputSources().isEmpty)
    }
}
