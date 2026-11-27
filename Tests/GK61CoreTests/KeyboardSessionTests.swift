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

    @Test("A command without a reply fails with noAcknowledgement after the timeout")
    func failsWithoutReply() async {
        let session = KeyboardSession(transport: FakeKeyboard(), acknowledgementTimeout: .milliseconds(50))

        await #expect(throws: KeyboardSessionError.noAcknowledgement(command: 0xA0)) {
            try await session.readPSD()
        }
    }
}
