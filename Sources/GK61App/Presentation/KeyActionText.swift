import GK61Core

/// One modifier bit with the names macOS uses for it.
struct ModifierChoice: Identifiable {
    let mask: ModifierMask
    let name: String
    let symbol: String

    var id: UInt8 { mask.rawValue }

    /// macOS menu order (⌃⌥⇧⌘), left side first.
    static let all: [ModifierChoice] = [
        ModifierChoice(mask: .leftControl, name: "Left Control", symbol: "⌃"),
        ModifierChoice(mask: .leftAlt, name: "Left Option", symbol: "⌥"),
        ModifierChoice(mask: .leftShift, name: "Left Shift", symbol: "⇧"),
        ModifierChoice(mask: .leftGUI, name: "Left Command", symbol: "⌘"),
        ModifierChoice(mask: .rightControl, name: "Right Control", symbol: "⌃"),
        ModifierChoice(mask: .rightAlt, name: "Right Option", symbol: "⌥"),
        ModifierChoice(mask: .rightShift, name: "Right Shift", symbol: "⇧"),
        ModifierChoice(mask: .rightGUI, name: "Right Command", symbol: "⌘"),
    ]
}

/// Text for what a key does, on keycaps and in the inspector.
enum KeyActionText {
    /// Compact form for a keycap, such as `⌘C`.
    static func symbol(for action: KeyAction) -> String {
        let modifiers = heldModifiers(of: action).map(\.symbol).joined()
        return modifiers + usages(of: action).map { KeyUsage.named($0)?.symbol ?? hex($0) }.joined()
    }

    /// Spelled-out form, such as `Left Command + C`.
    static func name(for action: KeyAction) -> String {
        let modifiers = heldModifiers(of: action).map(\.name)
        let keys = usages(of: action).map { KeyUsage.named($0)?.name ?? "Usage \(hex($0))" }
        let parts = modifiers + keys
        return parts.isEmpty ? "Nothing" : parts.joined(separator: " + ")
    }

    private static func heldModifiers(of action: KeyAction) -> [ModifierChoice] {
        ModifierChoice.all.filter { action.modifiers.contains($0.mask) }
    }

    private static func usages(of action: KeyAction) -> [UInt8] {
        [action.usage, action.secondUsage].filter { $0 != 0 }
    }

    private static func hex(_ usage: UInt8) -> String {
        "0x" + String(usage, radix: 16, uppercase: true)
    }
}
