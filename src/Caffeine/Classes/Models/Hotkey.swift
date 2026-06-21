//
//  Hotkey.swift
//  Caffeine
//
//  Lightweight value type describing a global hotkey binding.
//  Stores the Carbon virtual key code (`keyCode`) and modifier
//  mask (`modifiers`) so the value round-trips through
//  `UserDefaults` and back without losing information.
//
//  `Hotkey` is purely descriptive — registering it with macOS is
//  `HotkeyService`'s job. Keeping the value type separate from
//  the service makes it easy to inspect the stored binding in
//  unit tests and previews without spinning up Carbon.

import AppKit
import Carbon.HIToolbox

struct Hotkey: Equatable {
    /// Carbon virtual key code. See `Carbon.HIToolbox.Events.h`
    /// for the full list (e.g. `kVK_ANSI_C`, `kVK_ANSI_0`).
    var keyCode: UInt32

    /// Carbon modifier mask (`cmdKey`, `optionKey`, `controlKey`,
    /// `shiftKey`).
    var modifiers: UInt32

    static let none = Hotkey(keyCode: 0, modifiers: 0)

    var isSet: Bool {
        self.keyCode != 0 || self.modifiers != 0
    }

    // MARK: - Display

    /// Human-readable representation suitable for showing the
    /// user (e.g. "⌘⇧C").
    var displayString: String {
        if !self.isSet {
            return String(localized: "Not set")
        }
        var glyphs = ""
        if self.modifiers & UInt32(controlKey) != 0 { glyphs += "⌃" }
        if self.modifiers & UInt32(optionKey) != 0 { glyphs += "⌥" }
        if self.modifiers & UInt32(shiftKey) != 0 { glyphs += "⇧" }
        if self.modifiers & UInt32(cmdKey) != 0 { glyphs += "⌘" }
        glyphs += Self.keyName(for: self.keyCode)
        return glyphs
    }

    /// Translates the Carbon virtual key code into a single
    /// printable character or symbol. Falls back to the decimal
    /// code wrapped in angle brackets for any key we do not
    /// explicitly handle.
    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        // Letters
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        // Digits
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        // Special keys
        case kVK_Space: "Space"
        case kVK_Return: "↩"
        case kVK_Tab: "⇥"
        case kVK_Delete: "⌫"
        case kVK_ForwardDelete: "⌦"
        case kVK_Escape: "⎋"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        // Function keys
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default: "<\(keyCode)>"
        }
    }

    // MARK: - Modifier Conversion

    /// Converts an `NSEvent.ModifierFlags` (as delivered to a
    /// key-down event) into the Carbon modifier mask expected
    /// by `RegisterEventHotKey`.
    static func modifierMask(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }
}
