import GK61Core
import Testing

@Suite("Packet encoders")
struct PacketEncoderTests {
    @Test("GetPSD is A0 02 00 01 padded with zeros to 63 bytes")
    func getPSD() {
        let expected: [UInt8] = [0xA0, 0x02, 0x00, 0x01] + Array(repeating: 0, count: 59)

        #expect(Packet.getPSD.bytes == expected)
    }
}
