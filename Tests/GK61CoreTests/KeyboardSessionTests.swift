import GK61Core
import Testing

@Suite("Keyboard session")
struct KeyboardSessionTests {
    @Test("readPSD sends GetPSD and returns reply bytes 4 and 5")
    func readsPSD() async throws {
        let keyboard = FakeKeyboard { _ in [0xA0, 0x02, 0x00, 0x01, 0x0F, 0x0B] }
        let session = KeyboardSession(transport: keyboard)

        let psd = try await session.readPSD()

        #expect(psd == PSD(0x0F, 0x0B))
        #expect(keyboard.sentPayloads == [Packet.getPSD.bytes])
    }

    @Test("applyKeymap sends the 14 SetMatrix packets in order, each acknowledged by A0")
    func appliesKeymap() async throws {
        let keyboard = FakeKeyboard { sent in Array(sent.prefix(4)) }
        let session = KeyboardSession(transport: keyboard, pauseAfterChunk: .zero)
        let layout = try KeyLayout.gk61()

        try await session.applyKeymap(layout, actions: [63: .remap(toUsage: 0xE0)])

        #expect(keyboard.sentPayloads == Packet.keyMatrix(layout, actions: [63: .remap(toUsage: 0xE0)]).map(\.bytes))
    }

    @Test("applyKeymap with macro keys frees the buffers, uploads each key's macro in matrix order, then writes the matrix")
    func appliesKeymapWithMacros() async throws {
        let keyboard = FakeKeyboard { sent in Array(sent.prefix(4)) }
        let session = KeyboardSession(transport: keyboard, pauseAfterChunk: .zero, pauseAfterOperation: .zero)
        let layout = try KeyLayout.gk61()
        let tap = try Macro(playback: .repeatCount(1), steps: [MacroStep(.keyDown(usage: 0x04)), MacroStep(.keyUp(usage: 0x04))])
        let scroll = try Macro(playback: .untilReleased, steps: Array(repeating: MacroStep(.wheel(.down, notches: 1)), count: 20))
        let actions: [Int: KeyAction] = [63: .macro(tap), 21: .macro(scroll)]

        try await session.applyKeymap(layout, actions: actions)

        // Esc (21) comes first in matrix order, so its macro goes to buffer 1.
        let expected = [Packet.freeMacroBuffers]
            + Packet.macroUpload(scroll, bufferID: 1)
            + Packet.macroUpload(tap, bufferID: 2)
            + Packet.keyMatrix(layout, actions: actions)
        #expect(keyboard.sentPayloads == expected.map(\.bytes))
    }

    @Test("applyLighting sends the SetLED packets, each acknowledged by AE")
    func appliesLighting() async throws {
        let keyboard = FakeKeyboard { sent in Array(sent.prefix(4)) }
        let session = KeyboardSession(transport: keyboard, pauseAfterChunk: .zero)
        let breath = try #require(LightingMode.named("Breath"))
        let lighting = Lighting(mode: breath, speed: 1, brightness: 4, color: .rainbow)

        try await session.applyLighting(lighting)

        #expect(keyboard.sentPayloads == Packet.lighting(lighting).map(\.bytes))
    }

    @Test("A command without a reply fails with noAcknowledgement after the timeout")
    func failsWithoutReply() async {
        let session = KeyboardSession(transport: FakeKeyboard(), acknowledgementTimeout: .milliseconds(50))

        await #expect(throws: KeyboardSessionError.noAcknowledgement(command: 0xA0)) {
            try await session.readPSD()
        }
    }
}
