extension Packet {
    /// Releases every macro buffer before a new set is uploaded (fcn.00438190).
    public static let freeMacroBuffers = Packet([0xAA, 0x00])

    /// Allocates buffer `bufferID` and writes the macro body into it.
    public static func macroUpload(_ macro: Macro, bufferID: UInt8) -> [Packet] {
        let body = macro.body
        return [allocateMacroBuffer(bufferID, bodyLength: body.count)] + macroBodyChunks(body, bufferID: bufferID)
    }

    /// fcn.004380e0: the firmware wants 5 bytes more than the body.
    private static func allocateMacroBuffer(_ bufferID: UInt8, bodyLength: Int) -> Packet {
        let size = UInt16(bodyLength + 5)
        return Packet([0xA7, bufferID] + size.bigEndianBytes)
    }

    /// fcn.00438220: `A8 id 00 seq total length data…`, seq counting from 1.
    private static func macroBodyChunks(_ body: [UInt8], bufferID: UInt8) -> [Packet] {
        let offsets = Array(stride(from: 0, to: body.count, by: MacroChunk.dataCapacity))
        return offsets.enumerated().map { number, offset in
            let data = body[offset..<min(offset + MacroChunk.dataCapacity, body.count)]
            let header: [UInt8] = [0xA8, bufferID, 0x00, UInt8(number + 1), UInt8(offsets.count), UInt8(data.count)]
            return Packet(header + data)
        }
    }
}

private enum MacroChunk {
    static let dataCapacity = 57
}
