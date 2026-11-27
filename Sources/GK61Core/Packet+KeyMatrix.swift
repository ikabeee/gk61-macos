extension Packet {
    /// SetMatrix for the normal layer: the 126-entry key table split into 14 packets.
    /// Keys without an action get a zero code, which the firmware treats as its default.
    public static func keyMatrix(_ layout: KeyLayout, actions: [Int: KeyAction]) -> [Packet] {
        let table = keyTable(layout, actions: actions)
        return stride(from: 0, to: table.count, by: KeyMatrix.bytesPerPacket).enumerated().map { number, offset in
            keyMatrixPacket(sequence: UInt8(number + 1), data: table[offset..<offset + KeyMatrix.bytesPerPacket])
        }
    }

    private static func keyTable(_ layout: KeyLayout, actions: [Int: KeyAction]) -> [UInt8] {
        var table = [UInt8](repeating: 0, count: KeyMatrix.slotCount * KeyMatrix.bytesPerEntry)
        for key in layout.keys {
            let code = actions[key.matrixIndex]?.codeBytes ?? [0, 0, 0, 0]
            let entry = [UInt8(key.matrixIndex)] + code + [0]
            table.replaceSubrange(key.matrixIndex * KeyMatrix.bytesPerEntry ..< (key.matrixIndex + 1) * KeyMatrix.bytesPerEntry, with: entry)
        }
        return table
    }

    private static func keyMatrixPacket(sequence: UInt8, data: ArraySlice<UInt8>) -> Packet {
        let header: [UInt8] = [0xA0, 0x02, 0x04, sequence, 0x0E, 0xA5]
        return Packet(header + data + [0xA5])
    }
}

enum KeyMatrix {
    static let slotCount = 126
    static let bytesPerEntry = 6
    static let bytesPerPacket = 54
}
