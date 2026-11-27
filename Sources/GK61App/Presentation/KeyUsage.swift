import Foundation

/// Readable names for the HID keyboard usages (USB HID Usage Tables, page 0x07) a key can be remapped to.
struct KeyUsage: Identifiable, Hashable {
    enum Category: String, CaseIterable {
        case letters = "Letters"
        case digits = "Digits"
        case function = "Function Keys"
        case editing = "Editing and Navigation"
        case punctuation = "Punctuation"
        case modifiers = "Modifiers"
        case keypad = "Keypad"
    }

    let usage: UInt8
    let name: String
    /// Short text that fits on a keycap.
    let symbol: String
    let category: Category

    var id: UInt8 { usage }

    static func named(_ usage: UInt8) -> KeyUsage? {
        byUsage[usage]
    }

    static func matching(_ query: String) -> [KeyUsage] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedStandardContains(trimmed) || $0.symbol.localizedStandardContains(trimmed) }
    }

    static let all: [KeyUsage] = letters + digits + functionKeys + editing + punctuation + modifiers + keypad

    private static let byUsage = Dictionary(uniqueKeysWithValues: all.map { ($0.usage, $0) })

    private static let letters = (0..<26).map { offset in
        let letter = String(UnicodeScalar(UInt8(ascii: "A") + UInt8(offset)))
        return KeyUsage(usage: 0x04 + UInt8(offset), name: letter, symbol: letter, category: .letters)
    }

    private static let digits = (0..<10).map { offset in
        let digit = String((offset + 1) % 10)
        return KeyUsage(usage: 0x1E + UInt8(offset), name: digit, symbol: digit, category: .digits)
    }

    private static let functionKeys = (0..<24).map { offset in
        let name = "F\(offset + 1)"
        let usage = offset < 12 ? 0x3A + UInt8(offset) : 0x68 + UInt8(offset - 12)
        return KeyUsage(usage: usage, name: name, symbol: name, category: .function)
    }

    private static let editing: [KeyUsage] = [
        KeyUsage(usage: 0x28, name: "Return", symbol: "↩", category: .editing),
        KeyUsage(usage: 0x29, name: "Escape", symbol: "Esc", category: .editing),
        KeyUsage(usage: 0x2A, name: "Delete (Backspace)", symbol: "⌫", category: .editing),
        KeyUsage(usage: 0x2B, name: "Tab", symbol: "⇥", category: .editing),
        KeyUsage(usage: 0x2C, name: "Space", symbol: "Space", category: .editing),
        KeyUsage(usage: 0x39, name: "Caps Lock", symbol: "⇪", category: .editing),
        KeyUsage(usage: 0x46, name: "Print Screen", symbol: "PrtSc", category: .editing),
        KeyUsage(usage: 0x47, name: "Scroll Lock", symbol: "ScrLk", category: .editing),
        KeyUsage(usage: 0x48, name: "Pause", symbol: "Pause", category: .editing),
        KeyUsage(usage: 0x49, name: "Insert", symbol: "Ins", category: .editing),
        KeyUsage(usage: 0x4A, name: "Home", symbol: "↖", category: .editing),
        KeyUsage(usage: 0x4B, name: "Page Up", symbol: "⇞", category: .editing),
        KeyUsage(usage: 0x4C, name: "Forward Delete", symbol: "⌦", category: .editing),
        KeyUsage(usage: 0x4D, name: "End", symbol: "↘", category: .editing),
        KeyUsage(usage: 0x4E, name: "Page Down", symbol: "⇟", category: .editing),
        KeyUsage(usage: 0x4F, name: "Right Arrow", symbol: "→", category: .editing),
        KeyUsage(usage: 0x50, name: "Left Arrow", symbol: "←", category: .editing),
        KeyUsage(usage: 0x51, name: "Down Arrow", symbol: "↓", category: .editing),
        KeyUsage(usage: 0x52, name: "Up Arrow", symbol: "↑", category: .editing),
        KeyUsage(usage: 0x65, name: "Menu (Application)", symbol: "Menu", category: .editing),
    ]

    private static let punctuation: [KeyUsage] = [
        KeyUsage(usage: 0x2D, name: "Minus -", symbol: "-", category: .punctuation),
        KeyUsage(usage: 0x2E, name: "Equal =", symbol: "=", category: .punctuation),
        KeyUsage(usage: 0x2F, name: "Left Bracket [", symbol: "[", category: .punctuation),
        KeyUsage(usage: 0x30, name: "Right Bracket ]", symbol: "]", category: .punctuation),
        KeyUsage(usage: 0x31, name: "Backslash \\", symbol: "\\", category: .punctuation),
        KeyUsage(usage: 0x33, name: "Semicolon ;", symbol: ";", category: .punctuation),
        KeyUsage(usage: 0x34, name: "Quote '", symbol: "'", category: .punctuation),
        KeyUsage(usage: 0x35, name: "Grave Accent `", symbol: "`", category: .punctuation),
        KeyUsage(usage: 0x36, name: "Comma ,", symbol: ",", category: .punctuation),
        KeyUsage(usage: 0x37, name: "Period .", symbol: ".", category: .punctuation),
        KeyUsage(usage: 0x38, name: "Slash /", symbol: "/", category: .punctuation),
        KeyUsage(usage: 0x64, name: "Section § (ISO)", symbol: "§", category: .punctuation),
    ]

    private static let modifiers: [KeyUsage] = [
        KeyUsage(usage: 0xE0, name: "Left Control", symbol: "⌃", category: .modifiers),
        KeyUsage(usage: 0xE1, name: "Left Shift", symbol: "⇧", category: .modifiers),
        KeyUsage(usage: 0xE2, name: "Left Option (Alt)", symbol: "⌥", category: .modifiers),
        KeyUsage(usage: 0xE3, name: "Left Command (Windows)", symbol: "⌘", category: .modifiers),
        KeyUsage(usage: 0xE4, name: "Right Control", symbol: "⌃", category: .modifiers),
        KeyUsage(usage: 0xE5, name: "Right Shift", symbol: "⇧", category: .modifiers),
        KeyUsage(usage: 0xE6, name: "Right Option (Alt)", symbol: "⌥", category: .modifiers),
        KeyUsage(usage: 0xE7, name: "Right Command (Windows)", symbol: "⌘", category: .modifiers),
    ]

    private static let keypad: [KeyUsage] = [
        KeyUsage(usage: 0x53, name: "Num Lock (Clear)", symbol: "⌧", category: .keypad),
        KeyUsage(usage: 0x54, name: "Keypad /", symbol: "/", category: .keypad),
        KeyUsage(usage: 0x55, name: "Keypad *", symbol: "*", category: .keypad),
        KeyUsage(usage: 0x56, name: "Keypad -", symbol: "-", category: .keypad),
        KeyUsage(usage: 0x57, name: "Keypad +", symbol: "+", category: .keypad),
        KeyUsage(usage: 0x58, name: "Keypad Enter", symbol: "⌤", category: .keypad),
        KeyUsage(usage: 0x63, name: "Keypad .", symbol: ".", category: .keypad),
        KeyUsage(usage: 0x67, name: "Keypad =", symbol: "=", category: .keypad),
    ] + (0..<10).map { digit in
        let usage = digit == 0 ? 0x62 : 0x58 + UInt8(digit)
        return KeyUsage(usage: usage, name: "Keypad \(digit)", symbol: "\(digit)", category: .keypad)
    }
}
