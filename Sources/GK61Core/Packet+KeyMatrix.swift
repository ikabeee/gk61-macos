extension Packet {
    /// SetMatrix for the normal layer: the 126-entry key table split into 14 packets.
    /// Keys without an action get a zero code, which the firmware treats as its default.
    /// Macro keys point at the buffers `KeyboardSession.applyKeymap` uploads their macros to.
    public static func keyMatrix(_ layout: KeyLayout, actions: [Int: KeyAction]) -> [Packet] {
        keyMatrixPackets(layer: .normal, table: keyTable(layout, actions: actions))
    }

    /// SetFnMatrix: what each key sends while Fn is held. Keys without an action keep their factory
    /// Fn function. The Windows driver always sends the Fn table right after the normal one; the
    /// firmware only takes the new keymap once both arrive. Macros are not supported on the Fn layer.
    public static func fnKeyMatrix(_ layout: KeyLayout, actions: [Int: KeyAction]) -> [Packet] {
        keyMatrixPackets(layer: .fn, table: keyTable(layout, actions: actions))
    }

    /// SetFnMatrix with every key on its factory Fn function.
    public static func defaultFnKeyMatrix(_ layout: KeyLayout) -> [Packet] {
        fnKeyMatrix(layout, actions: [:])
    }

    private static func keyTable(_ layout: KeyLayout, actions: [Int: KeyAction]) -> [UInt8] {
        let macroBufferIDs = Dictionary(uniqueKeysWithValues: MacroBuffer.assign(layout, actions: actions).map { ($0.matrixIndex, $0.id) })
        var table = [UInt8](repeating: 0, count: KeyMatrix.slotCount * KeyMatrix.bytesPerEntry)
        for key in layout.keys {
            let bufferID = macroBufferIDs[key.matrixIndex] ?? 0
            let code = actions[key.matrixIndex]?.codeBytes(macroBufferID: bufferID) ?? [0, 0, 0, 0]
            let entry = [UInt8(key.matrixIndex)] + code + [0]
            table.replaceSubrange(key.matrixIndex * KeyMatrix.bytesPerEntry ..< (key.matrixIndex + 1) * KeyMatrix.bytesPerEntry, with: entry)
        }
        return table
    }

    private static func keyMatrixPackets(layer: KeyMatrix.Layer, table: [UInt8]) -> [Packet] {
        stride(from: 0, to: table.count, by: KeyMatrix.bytesPerPacket).enumerated().map { number, offset in
            let header: [UInt8] = [0xA0, 0x02, layer.rawValue, UInt8(number + 1), 0x0E, 0xA5]
            return Packet(header + table[offset..<offset + KeyMatrix.bytesPerPacket] + [0xA5])
        }
    }
}

enum KeyMatrix {
    /// Third header byte of a matrix write.
    enum Layer: UInt8 {
        case normal = 0x04
        case fn = 0x05
    }

    static let slotCount = 126
    static let bytesPerEntry = 6
    static let bytesPerPacket = 54
}
