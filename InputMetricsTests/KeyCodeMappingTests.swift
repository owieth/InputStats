import XCTest
import Carbon.HIToolbox
@testable import InputMetrics

final class KeyCodeMappingTests: XCTestCase {

    // MARK: - Number row

    func testNumberKeys() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_1), "1")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_2), "2")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_3), "3")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_4), "4")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_5), "5")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_6), "6")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_7), "7")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_8), "8")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_9), "9")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_0), "0")
    }

    func testGraveKey() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Grave), "^")
    }

    func testMinusKey() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Minus), "\u{00DF}") // ß
    }

    func testEqualKey() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Equal), "\u{00B4}") // ´
    }

    // MARK: - QWERTZ letter keys

    func testTopRowLetters() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Q), "Q")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_W), "W")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_E), "E")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_R), "R")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_T), "T")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_U), "U")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_I), "I")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_O), "O")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_P), "P")
    }

    func testQwertzYZSwap() {
        // kVK_ANSI_Y (physical Y position) maps to "Z" in QWERTZ
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Y), "Z")
        // kVK_ANSI_Z (physical Z position) maps to "Y" in QWERTZ
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Z), "Y")
    }

    func testMiddleRowLetters() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_A), "A")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_S), "S")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_D), "D")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_F), "F")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_G), "G")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_H), "H")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_J), "J")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_K), "K")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_L), "L")
    }

    func testGermanUmlauts() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_LeftBracket), "\u{00DC}") // Ü
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Semicolon), "\u{00D6}") // Ö
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Quote), "\u{00C4}") // Ä
    }

    func testBottomRowLetters() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_X), "X")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_C), "C")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_V), "V")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_B), "B")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_N), "N")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_M), "M")
    }

    func testPunctuationKeys() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Comma), ",")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Period), ".")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Slash), "-")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_RightBracket), "+")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_ANSI_Backslash), "'")
    }

    // MARK: - Special keys

    func testSpecialKeys() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Space), "Space")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Return), "\u{21B5}") // ↵
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Tab), "\u{21E5}") // ⇥
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Delete), "\u{232B}") // ⌫
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Escape), "\u{238B}") // ⎋
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_CapsLock), "\u{21EA}") // ⇪
    }

    // MARK: - Modifier keys

    func testModifierKeys() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Shift), "\u{21E7}") // ⇧
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_RightShift), "\u{21E7}") // ⇧
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Control), "\u{2303}") // ⌃
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_RightControl), "\u{2303}") // ⌃
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Option), "\u{2325}") // ⌥
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_RightOption), "\u{2325}") // ⌥
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Command), "\u{2318}") // ⌘
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_RightCommand), "\u{2318}") // ⌘
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_Function), "fn")
    }

    func testLeftAndRightModifiersMatch() {
        XCTAssertEqual(
            KeyCodeMapping.keyName(for: kVK_Shift),
            KeyCodeMapping.keyName(for: kVK_RightShift)
        )
        XCTAssertEqual(
            KeyCodeMapping.keyName(for: kVK_Control),
            KeyCodeMapping.keyName(for: kVK_RightControl)
        )
        XCTAssertEqual(
            KeyCodeMapping.keyName(for: kVK_Option),
            KeyCodeMapping.keyName(for: kVK_RightOption)
        )
        XCTAssertEqual(
            KeyCodeMapping.keyName(for: kVK_Command),
            KeyCodeMapping.keyName(for: kVK_RightCommand)
        )
    }

    // MARK: - Arrow keys

    func testArrowKeys() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_LeftArrow), "\u{2190}") // ←
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_RightArrow), "\u{2192}") // →
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_UpArrow), "\u{2191}") // ↑
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_DownArrow), "\u{2193}") // ↓
    }

    // MARK: - Function keys

    func testFunctionKeys() {
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F1), "F1")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F2), "F2")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F3), "F3")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F4), "F4")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F5), "F5")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F6), "F6")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F7), "F7")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F8), "F8")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F9), "F9")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F10), "F10")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F11), "F11")
        XCTAssertEqual(KeyCodeMapping.keyName(for: kVK_F12), "F12")
    }

    // MARK: - Unknown key code

    func testUnknownKeyCodeReturnsFallback() {
        let result = KeyCodeMapping.keyName(for: 999)
        XCTAssertEqual(result, "Key999")
    }

    func testUnknownKeyCodeFormat() {
        let result = KeyCodeMapping.keyName(for: 200)
        XCTAssertTrue(result.hasPrefix("Key"))
    }

    // MARK: - QWERTZ layout structure

    func testQwertzLayoutHasFiveRows() {
        XCTAssertEqual(KeyCodeMapping.qwertzLayout.count, 5)
    }

    func testQwertzLayoutFirstRowStartsWithCaret() {
        XCTAssertEqual(KeyCodeMapping.qwertzLayout[0].first, "^")
    }

    func testQwertzLayoutFirstRowEndsWithBackspace() {
        XCTAssertEqual(KeyCodeMapping.qwertzLayout[0].last, "\u{232B}") // ⌫
    }

    func testQwertzLayoutContainsSpaceBar() {
        let bottomRow = KeyCodeMapping.qwertzLayout[4]
        let hasSpace = bottomRow.contains { $0.contains("Space") }
        XCTAssertTrue(hasSpace)
    }
}
