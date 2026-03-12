import Foundation
import Carbon.HIToolbox

struct KeyCodeMapping {
    static func keyName(for keyCode: Int) -> String {
        // QWERTZ keyboard layout mapping
        switch keyCode {
        // Number row
        case kVK_ANSI_Grave: return "^"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_Minus: return "ß"
        case kVK_ANSI_Equal: return "´"

        // Top letter row (QWERTZ)
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_Y: return "Z" // QWERTZ swap
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_LeftBracket: return "Ü"
        case kVK_ANSI_RightBracket: return "+"

        // Middle letter row
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_Semicolon: return "Ö"
        case kVK_ANSI_Quote: return "Ä"
        case kVK_ANSI_Backslash: return "'"

        // Bottom letter row (QWERTZ)
        case kVK_ANSI_Z: return "Y" // QWERTZ swap
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "-"

        // Special keys
        case kVK_Space: return "Space"
        case kVK_Return: return "↵"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_CapsLock: return "⇪"

        // Modifiers
        case kVK_Shift: return "⇧"
        case kVK_RightShift: return "⇧"
        case kVK_Control: return "⌃"
        case kVK_RightControl: return "⌃"
        case kVK_Option: return "⌥"
        case kVK_RightOption: return "⌥"
        case kVK_Command: return "⌘"
        case kVK_RightCommand: return "⌘"
        case kVK_Function: return "fn"

        // Arrow keys
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"

        // Function keys
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"

        default:
            return "Key\(keyCode)"
        }
    }

    static let qwertzLayoutWithCodes: [[(keyCode: Int, label: String, width: CGFloat)]] = [
        // Number row
        [(50, "^", 1), (18, "1", 1), (19, "2", 1), (20, "3", 1), (21, "4", 1), (23, "5", 1), (22, "6", 1), (26, "7", 1), (28, "8", 1), (25, "9", 1), (29, "0", 1), (27, "ß", 1), (24, "´", 1)],
        // QWERTZ row
        [(12, "Q", 1), (13, "W", 1), (14, "E", 1), (15, "R", 1), (17, "T", 1), (16, "Z", 1), (32, "U", 1), (34, "I", 1), (31, "O", 1), (35, "P", 1), (33, "Ü", 1), (30, "+", 1)],
        // ASDF row
        [(0, "A", 1), (1, "S", 1), (2, "D", 1), (3, "F", 1), (5, "G", 1), (4, "H", 1), (38, "J", 1), (40, "K", 1), (37, "L", 1), (41, "Ö", 1), (39, "Ä", 1), (42, "#", 1)],
        // YXCV row
        [(6, "Y", 1), (7, "X", 1), (8, "C", 1), (9, "V", 1), (11, "B", 1), (45, "N", 1), (46, "M", 1), (43, ",", 1), (47, ".", 1), (44, "-", 1)],
        // Space row
        [(49, "Space", 6)]
    ]

    static let qwertzLayout: [[String]] = [
        ["^", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß", "´", "⌫"],
        ["⇥", "Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "Ü", "+", ""],
        ["⇪", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Ö", "Ä", "'", "↵"],
        ["⇧", "<", "Y", "X", "C", "V", "B", "N", "M", ",", ".", "-", "⇧", ""],
        ["fn", "⌃", "⌥", "⌘", "        Space        ", "⌘", "⌥", "←", "↑↓", "→"]
    ]
}
