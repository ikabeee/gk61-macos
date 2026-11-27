import GK61HID
import Testing

@Suite("macOS key code to HID usage")
struct MacKeyCodeTests {
    @Test(
        "Maps macOS virtual key codes to HID keyboard usages",
        arguments: [
            (0x00, 0x04),  // A
            (0x24, 0x28),  // Return
            (0x35, 0x29),  // Escape
            (0x33, 0x2A),  // Delete (Backspace)
            (0x7A, 0x3A),  // F1
            (0x7B, 0x50),  // Left Arrow
            (0x3B, 0xE0),  // Left Control
            (0x37, 0xE3),  // Left Command
            (0x3D, 0xE6),  // Right Option
            (0x36, 0xE7),  // Right Command
        ] as [(UInt16, UInt8)])
    func mapsKnownKeys(keyCode: UInt16, usage: UInt8) {
        #expect(MacKeyCode.hidUsage(for: keyCode) == usage)
    }

    @Test("The Fn key has no HID usage")
    func hasNoUsageForFn() {
        #expect(MacKeyCode.hidUsage(for: 0x3F) == nil)
    }
}
