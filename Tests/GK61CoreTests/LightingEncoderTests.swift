import GK61Core
import Testing

@Suite("Packet encoders: lighting")
struct LightingEncoderTests {
    @Test("Breath in red sends AE 01 00 00 05 speed brightness with color index + 1")
    func breathInRed() throws {
        let breath = try #require(LightingMode.named("Breath"))
        let lighting = Lighting(mode: breath, speed: 2, brightness: 4, color: .palette(.red))

        #expect(Packet.lighting(lighting).map(\.bytes) == [[0xAE, 0x01, 0x00, 0x00, 0x05, 0x02, 0x04, 0x01] + zeros(55)])
    }

    @Test("Breath in rainbow sends color byte 0")
    func breathInRainbow() throws {
        let breath = try #require(LightingMode.named("Breath"))
        let lighting = Lighting(mode: breath, speed: 2, brightness: 4, color: .rainbow)

        #expect(Packet.lighting(lighting).first?.bytes[7] == 0x00)
    }

    @Test("Always lighting in blue sends the palette index itself")
    func alwaysLightingInBlue() throws {
        let alwaysOn = try #require(LightingMode.named("Always lighting"))
        let lighting = Lighting(mode: alwaysOn, speed: 0, brightness: 4, color: .palette(.blue))

        #expect(Packet.lighting(lighting).first?.bytes[4...7] == [0x07, 0x00, 0x04, 0x02])
    }

    @Test("Custom mode 1 sends all 126 slots as [slot|80 R G B] plus FF over 10 packets with color byte FF")
    func customModePerKeyColors() throws {
        let custom = try #require(LightingMode.named("Custom mode 1"))
        let escRed = [21: RGBColor(red: 0xFF, green: 0x10, blue: 0x00)]
        let lighting = Lighting(mode: custom, speed: 0, brightness: 3, color: .perKey(escRed))

        let packets = Packet.lighting(lighting).map(\.bytes)

        #expect(packets.count == 10)
        #expect(packets.allSatisfy { $0[0...7] == [0xAE, 0x01, 0x00, 0x00, 0x19, 0x00, 0x03, 0xFF] })
        #expect(packets[0][8...15] == [0x80, 0, 0, 0, 0x81, 0, 0, 0])
        // Slot 21 is the 9th entry of packet 2 (13 entries per packet).
        #expect(packets[1][(8 + 8 * 4)...(8 + 8 * 4 + 3)] == [0x95, 0xFF, 0x10, 0x00])
        // Packet 10 holds slots 117…125 (36 bytes), then the FF terminator.
        #expect(packets[9][(8 + 32)...(8 + 36)] == [0xFD, 0, 0, 0, 0xFF])
    }

    private func zeros(_ count: Int) -> [UInt8] {
        Array(repeating: 0, count: count)
    }
}
