import GK61Core
import Testing

@Suite("Macro encoders")
struct MacroEncoderTests {
    /// Every macro body starts with `01` and 30 zero bytes (fcn.00408860).
    private let header: [UInt8] = [0x01] + Array(repeating: 0, count: 30)

    @Test("A key press is key down 02 then key up 03, after the 31-byte header")
    func keyPress() throws {
        let macro = try Macro(playback: .repeatCount(1), steps: [
            MacroStep(.keyDown(usage: 0x04)),
            MacroStep(.keyUp(usage: 0x04)),
        ])

        #expect(macro.body == header + [0x02, 0x04, 0x03, 0x04])
    }

    @Test("A nonzero delay follows its event as 01 and the milliseconds big-endian")
    func delayAfterEvent() throws {
        let macro = try Macro(playback: .repeatCount(1), steps: [
            MacroStep(.keyDown(usage: 0xE1), delayMilliseconds: 300),
        ])

        #expect(macro.body == header + [0x02, 0xE1, 0x01, 0x01, 0x2C])
    }

    @Test("Mouse buttons are down 04 / up 05 with 1 left, 2 right, 3 middle")
    func mouseButtons() throws {
        let macro = try Macro(playback: .repeatCount(1), steps: [
            MacroStep(.mouseDown(.left)),
            MacroStep(.mouseUp(.left)),
            MacroStep(.mouseDown(.right)),
            MacroStep(.mouseUp(.middle)),
        ])

        #expect(macro.body == header + [0x04, 0x01, 0x05, 0x01, 0x04, 0x02, 0x05, 0x03])
    }

    @Test("A wheel turn repeats 08 00 (up) or 09 00 (down) once per notch")
    func wheel() throws {
        let macro = try Macro(playback: .repeatCount(1), steps: [
            MacroStep(.wheel(.up, notches: 2)),
            MacroStep(.wheel(.down, notches: 1)),
        ])

        #expect(macro.body == header + [0x08, 0x00, 0x08, 0x00, 0x09, 0x00])
    }

    @Test("A macro whose body exceeds the 512-byte buffer is rejected")
    func rejectsOversizedBody() {
        // 31 header bytes + 241 events × 2 bytes = 513 bytes.
        let steps = Array(repeating: MacroStep(.keyDown(usage: 0x04)), count: 241)

        #expect(throws: MacroError.bodyTooLong(byteCount: 513)) {
            try Macro(playback: .repeatCount(1), steps: steps)
        }
    }

    @Test("Freeing all macro buffers is AA 00 padded to 63 bytes")
    func freeMacroBuffers() {
        #expect(Packet.freeMacroBuffers.bytes == [0xAA, 0x00] + Array(repeating: 0, count: 61))
    }

    @Test("An upload starts with A7, the buffer id and body length + 5 big-endian")
    func allocatesBuffer() throws {
        // 31 + 110 × 2 = 251-byte body → buffer size 256 = 01 00.
        let macro = try Macro(playback: .repeatCount(1), steps: Array(repeating: MacroStep(.keyDown(usage: 0x04)), count: 110))

        let packets = Packet.macroUpload(macro, bufferID: 2)

        #expect(packets[0].bytes == [0xA7, 0x02, 0x01, 0x00] + Array(repeating: 0, count: 59))
    }

    @Test("The body follows in A8 chunks of at most 57 bytes: id, 00, seq from 1, total, chunk length, data at 6")
    func writesBodyInChunks() throws {
        // 251-byte body → 5 chunks: 4 × 57 + 23.
        let macro = try Macro(playback: .repeatCount(1), steps: Array(repeating: MacroStep(.keyDown(usage: 0x04)), count: 110))
        let keyDownPair: [UInt8] = [0x02, 0x04]

        let packets = Packet.macroUpload(macro, bufferID: 2)

        #expect(packets.count == 1 + 5)
        let firstChunk: [UInt8] = [0xA8, 0x02, 0x00, 0x01, 0x05, 57] + header + Array(repeating: keyDownPair, count: 13).flatMap { $0 }
        #expect(packets[1].bytes == firstChunk)
        #expect(packets[4].bytes[0...5] == [0xA8, 0x02, 0x00, 0x04, 0x05, 57])
        let lastChunk: [UInt8] = [0xA8, 0x02, 0x00, 0x05, 0x05, 23] + [0x04] + Array(repeating: keyDownPair, count: 11).flatMap { $0 }
        #expect(packets[5].bytes == lastChunk + Array(repeating: 0, count: 63 - lastChunk.count))
    }

    @Test("A key playing a macro a set number of times is F3, buffer id, count big-endian")
    func repeatCountKeyEntry() throws {
        let macro = try Macro(playback: .repeatCount(0x0102), steps: [MacroStep(.keyDown(usage: 0x04))])

        let packets = Packet.keyMatrix(try KeyLayout.gk61(), actions: [63: .macro(macro)])

        // CapsLock (index 63) is the only macro key, so it gets buffer 1.
        #expect(packets[7].bytes[6...11] == [63, 0xF3, 0x01, 0x01, 0x02, 0x00])
    }

    @Test("A key repeating a macro until it is released is F0, buffer id, 00 00")
    func untilReleasedKeyEntry() throws {
        let macro = try Macro(playback: .untilReleased, steps: [MacroStep(.keyDown(usage: 0x04))])

        let packets = Packet.keyMatrix(try KeyLayout.gk61(), actions: [63: .macro(macro)])

        #expect(packets[7].bytes[6...11] == [63, 0xF0, 0x01, 0x00, 0x00, 0x00])
    }

    @Test("A key repeating a macro until it is pressed again is F1, buffer id, 00 00")
    func untilPressedAgainKeyEntry() throws {
        let macro = try Macro(playback: .untilPressedAgain, steps: [MacroStep(.keyDown(usage: 0x04))])

        let packets = Packet.keyMatrix(try KeyLayout.gk61(), actions: [63: .macro(macro)])

        #expect(packets[7].bytes[6...11] == [63, 0xF1, 0x01, 0x00, 0x00, 0x00])
    }

    @Test("Macro keys get buffers 1, 2, … in matrix order, one per key even when they share a macro")
    func bufferIDsFollowMatrixOrder() throws {
        let macro = try Macro(playback: .untilReleased, steps: [MacroStep(.keyDown(usage: 0x04))])

        let packets = Packet.keyMatrix(try KeyLayout.gk61(), actions: [63: .macro(macro), 21: .macro(macro)])

        // Esc (index 21) → packet 3, data offset 18; CapsLock (index 63) → packet 8, data offset 0.
        #expect(packets[2].bytes[(6 + 18)...(6 + 23)] == [21, 0xF0, 0x01, 0x00, 0x00, 0x00])
        #expect(packets[7].bytes[6...11] == [63, 0xF0, 0x02, 0x00, 0x00, 0x00])
    }
}
