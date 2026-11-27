import GK61Core

// `if case` instead of `switch`: the core is growing new action kinds (macros),
// and these accessors only describe key/combination actions.
extension KeyAction {
    var modifiers: ModifierMask {
        guard case let .keys(modifiers, _, _) = self else { return [] }
        return modifiers
    }

    var usage: UInt8 {
        guard case let .keys(_, usage, _) = self else { return 0 }
        return usage
    }

    var secondUsage: UInt8 {
        guard case let .keys(_, _, secondUsage) = self else { return 0 }
        return secondUsage
    }

    var macroPlayback: MacroPlayback? {
        guard case let .macro(macro) = self else { return nil }
        return macro.playback
    }

    /// HID usages E0–E7 are the eight modifier keys.
    static func isModifierUsage(_ usage: UInt8) -> Bool {
        (0xE0...0xE7).contains(usage)
    }

    /// The action the firmware performs for a key with no entry.
    static func firmwareDefault(of key: KeyLayout.Key) -> KeyAction {
        .keys(modifiers: [], usage: key.defaultUsage ?? 0, secondUsage: 0)
    }
}

extension [Int: KeyAction] {
    /// What the key does with this keymap: its entry, or the firmware default when it has none.
    func effectiveAction(of key: KeyLayout.Key) -> KeyAction {
        self[key.id] ?? .firmwareDefault(of: key)
    }
}
