import GK61Core
import Testing

@Suite("Packet encoders")
struct PacketEncoderTests {
    @Test("GetPSD is A0 02 00 01 padded with zeros to 63 bytes")
    func getPSD() {
        let expected: [UInt8] = [0xA0, 0x02, 0x00, 0x01] + Array(repeating: 0, count: 59)

        #expect(Packet.getPSD.bytes == expected)
    }

    @Test("An unchanged layout is 14 SetMatrix packets carrying each key's index with a zero code")
    func unchangedKeyMatrix() throws {
        let packets = Packet.keyMatrix(try KeyLayout.gk61(), actions: [:])

        #expect(packets.count == 14)
        #expect(packets[2].bytes[0...5] == [0xA0, 0x02, 0x04, 0x03, 0x0E, 0xA5])
        #expect(packets[2].bytes[60] == 0xA5)
        // Esc is matrix index 21 → table offset 126 → packet 3, data offset 18.
        #expect(packets[2].bytes[(6 + 18)...(6 + 23)] == [21, 0, 0, 0, 0, 0])
        // Index 20 has no key: its whole entry stays zero.
        #expect(packets[2].bytes[(6 + 12)...(6 + 17)] == [0, 0, 0, 0, 0, 0])
    }

    @Test("Remapping CapsLock to Left Control sends the modifier as mask bit 01")
    func remapsToModifier() throws {
        let packets = Packet.keyMatrix(try KeyLayout.gk61(), actions: [63: .remap(toUsage: 0xE0)])

        // CapsLock is matrix index 63 → table offset 378 → packet 8, data offset 0.
        #expect(packets[7].bytes[6...11] == [63, 0xFC, 0x01, 0x00, 0x00, 0x00])
    }

    @Test("Remapping a key to A sends usage 04 with no modifiers")
    func remapsToKey() throws {
        let packets = Packet.keyMatrix(try KeyLayout.gk61(), actions: [63: .remap(toUsage: 0x04)])

        #expect(packets[7].bytes[6...11] == [63, 0xFC, 0x00, 0x04, 0x00, 0x00])
    }

    @Test("The default Fn matrix is 14 SetFnMatrix packets naming every key with a zero (firmware default) code")
    func encodesDefaultFnMatrix() throws {
        let packets = Packet.defaultFnKeyMatrix(try KeyLayout.gk61())

        #expect(packets.count == 14)
        #expect(packets[2].bytes[0...5] == [0xA0, 0x02, 0x05, 0x03, 0x0E, 0xA5])
        #expect(packets[2].bytes[60] == 0xA5)
        // Esc is matrix index 21 → packet 3, data offset 18.
        #expect(packets[2].bytes[(6 + 18)...(6 + 23)] == [21, 0, 0, 0, 0, 0])
        // Fn is matrix index 118 → table offset 708 → packet 14, data offset 6.
        #expect(packets[13].bytes[(6 + 6)...(6 + 11)] == [118, 0, 0, 0, 0, 0])
    }

    @Test("SetFnMatrix carries the Fn-layer actions: Fn+Enter sending F24")
    func encodesFnLayerActions() throws {
        let packets = Packet.fnKeyMatrix(try KeyLayout.gk61(), actions: [76: .remap(toUsage: 0x73)])

        #expect(packets.count == 14)
        // Enter is matrix index 76 → table offset 456 → packet 9, data offset 24.
        #expect(packets[8].bytes[0...5] == [0xA0, 0x02, 0x05, 0x09, 0x0E, 0xA5])
        #expect(packets[8].bytes[(6 + 24)...(6 + 29)] == [76, 0xFC, 0x00, 0x73, 0x00, 0])
    }

    @Test("The keyboard toggles put Fn+Enter on F24 and Fn+Left Win on F23")
    func keyboardToggleFnActions() throws {
        let actions = KeyboardToggle.fnActions(for: try KeyLayout.gk61())

        #expect(actions == [76: .remap(toUsage: 0x73), 106: .remap(toUsage: 0x72)])
    }

    @Test("Cmd lock leaves Left Win to the keyboard's own Win lock: only arrow mode changes keys on the Mac")
    func commandLockHasNoMacMapping() {
        #expect(KeyboardToggle.macMapping(for: [.commandLock]).isEmpty)
        #expect(KeyboardToggle.macMapping(for: [.arrowMode, .commandLock]) == ArrowMode.swappedUsages)
    }
}
