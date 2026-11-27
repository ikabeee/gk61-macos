import GK61Core
import Testing

@Suite("Macro recording")
struct MacroRecordingTests {
    @Test("Each recorded key becomes a step whose delay is the time until the next one; the last step has none")
    func timesStepsByTheGapToTheNextEvent() {
        let events = [
            RecordedKeyEvent(usage: 0x04, isDown: true, time: .milliseconds(0)),
            RecordedKeyEvent(usage: 0x04, isDown: false, time: .milliseconds(80)),
            RecordedKeyEvent(usage: 0x05, isDown: true, time: .milliseconds(230)),
            RecordedKeyEvent(usage: 0x05, isDown: false, time: .milliseconds(300)),
        ]

        #expect(MacroRecording.steps(from: events) == [
            MacroStep(.keyDown(usage: 0x04), delayMilliseconds: 80),
            MacroStep(.keyUp(usage: 0x04), delayMilliseconds: 150),
            MacroStep(.keyDown(usage: 0x05), delayMilliseconds: 70),
            MacroStep(.keyUp(usage: 0x05)),
        ])
    }

    @Test("A pause longer than the firmware's 16-bit delay is clamped to 65535 ms")
    func clampsLongPauses() {
        let events = [
            RecordedKeyEvent(usage: 0x04, isDown: true, time: .zero),
            RecordedKeyEvent(usage: 0x04, isDown: false, time: .seconds(90)),
        ]

        #expect(MacroRecording.steps(from: events).first?.delayMilliseconds == 65535)
    }

    @Test("Auto-repeat presses of a key already held are dropped, and the gap runs to the next kept event")
    func dropsAutoRepeat() {
        let events = [
            RecordedKeyEvent(usage: 0x04, isDown: true, time: .zero),
            RecordedKeyEvent(usage: 0x04, isDown: true, time: .milliseconds(500)),
            RecordedKeyEvent(usage: 0x04, isDown: true, time: .milliseconds(533)),
            RecordedKeyEvent(usage: 0x04, isDown: false, time: .milliseconds(600)),
        ]

        #expect(MacroRecording.steps(from: events) == [
            MacroStep(.keyDown(usage: 0x04), delayMilliseconds: 600),
            MacroStep(.keyUp(usage: 0x04)),
        ])
    }

    @Test("A release without a recorded press is dropped")
    func dropsReleasesOfKeysHeldBeforeRecording() {
        let events = [
            RecordedKeyEvent(usage: 0xE3, isDown: false, time: .zero),
            RecordedKeyEvent(usage: 0x04, isDown: true, time: .milliseconds(40)),
            RecordedKeyEvent(usage: 0x04, isDown: false, time: .milliseconds(90)),
        ]

        #expect(MacroRecording.steps(from: events) == [
            MacroStep(.keyDown(usage: 0x04), delayMilliseconds: 50),
            MacroStep(.keyUp(usage: 0x04)),
        ])
    }

    @Test("Keys still down when recording stops are released at the end, in the order they were pressed")
    func releasesKeysHeldAtTheEnd() {
        let events = [
            RecordedKeyEvent(usage: 0xE3, isDown: true, time: .zero),
            RecordedKeyEvent(usage: 0x06, isDown: true, time: .milliseconds(30)),
        ]

        #expect(MacroRecording.steps(from: events) == [
            MacroStep(.keyDown(usage: 0xE3), delayMilliseconds: 30),
            MacroStep(.keyDown(usage: 0x06)),
            MacroStep(.keyUp(usage: 0xE3)),
            MacroStep(.keyUp(usage: 0x06)),
        ])
    }
}
