/// Modifier bits as the firmware encodes them in a key entry (same order as the HID modifier byte).
public struct ModifierMask: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let leftControl = ModifierMask(rawValue: 0x01)
    public static let leftShift = ModifierMask(rawValue: 0x02)
    public static let leftAlt = ModifierMask(rawValue: 0x04)
    public static let leftGUI = ModifierMask(rawValue: 0x08)
    public static let rightControl = ModifierMask(rawValue: 0x10)
    public static let rightShift = ModifierMask(rawValue: 0x20)
    public static let rightAlt = ModifierMask(rawValue: 0x40)
    public static let rightGUI = ModifierMask(rawValue: 0x80)
}

/// What a key does after remapping.
public enum KeyAction: Hashable, Sendable {
    /// Modifiers plus up to two HID keyboard usages pressed together (0 = none).
    case keys(modifiers: ModifierMask, usage: UInt8, secondUsage: UInt8)
    /// Plays a macro stored on the keyboard; `KeyboardSession.applyKeymap` uploads it.
    case macro(Macro)

    /// Makes the key send one HID usage. Modifier usages (E0–E7) become mask bits,
    /// as the Windows driver does when it loads its key table.
    public static func remap(toUsage usage: UInt8) -> KeyAction {
        guard (0xE0...0xE7).contains(usage) else {
            return .keys(modifiers: [], usage: usage, secondUsage: 0)
        }
        return .keys(modifiers: ModifierMask(rawValue: 1 << (usage - 0xE0)), usage: 0, secondUsage: 0)
    }

    /// The 4 code bytes of a key-matrix entry. A macro entry names the buffer its macro is uploaded to.
    func codeBytes(macroBufferID: UInt8) -> [UInt8] {
        switch self {
        case let .keys(modifiers, usage, secondUsage):
            [0xFC, modifiers.rawValue, usage, secondUsage]
        case let .macro(macro):
            macro.playback.keyEntry(bufferID: macroBufferID)
        }
    }
}
