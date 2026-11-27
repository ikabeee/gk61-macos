/// The firmware buffer one macro key's macro is uploaded to during an Apply.
struct MacroBuffer {
    let id: UInt8
    let matrixIndex: Int
    let macro: Macro

    /// Like the Windows driver (fcn.00408ea0), every macro key gets its own buffer, even when
    /// keys share a macro, numbered 1, 2, … in matrix order.
    static func assign(_ layout: KeyLayout, actions: [Int: KeyAction]) -> [MacroBuffer] {
        let macroKeys = layout.keys.map(\.matrixIndex).sorted().compactMap { index in
            macro(of: actions[index]).map { (matrixIndex: index, macro: $0) }
        }
        return macroKeys.enumerated().map { position, key in
            MacroBuffer(id: UInt8(position + 1), matrixIndex: key.matrixIndex, macro: key.macro)
        }
    }

    private static func macro(of action: KeyAction?) -> Macro? {
        guard case let .macro(macro) = action else { return nil }
        return macro
    }
}
