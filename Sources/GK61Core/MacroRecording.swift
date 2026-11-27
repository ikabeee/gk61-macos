/// A key press or release captured while recording a macro, timed from the start of the recording.
public struct RecordedKeyEvent: Hashable, Sendable {
    /// HID keyboard usage; modifiers are usages E0–E7.
    public let usage: UInt8
    public let isDown: Bool
    public let time: Duration

    public init(usage: UInt8, isDown: Bool, time: Duration) {
        self.usage = usage
        self.isDown = isDown
        self.time = time
    }
}

/// Turns what the user typed while recording into the steps the keyboard plays back.
public enum MacroRecording {
    public static func steps(from recorded: [RecordedKeyEvent]) -> [MacroStep] {
        let events = keyTransitions(in: recorded)
        return events.indices.map { index in
            let event = events[index]
            let next = events.indices.contains(index + 1) ? events[index + 1] : nil
            return MacroStep(macroEvent(of: event), delayMilliseconds: next.map { milliseconds(from: event.time, to: $0.time) } ?? 0)
        }
    }

    /// Keeps only real presses and releases: drops auto-repeat and releases of keys pressed before
    /// recording began, then releases whatever is still down so playback never leaves a key stuck.
    private static func keyTransitions(in recorded: [RecordedKeyEvent]) -> [RecordedKeyEvent] {
        var held: [UInt8] = []
        let transitions = recorded.filter { event in
            let isHeld = held.contains(event.usage)
            guard event.isDown != isHeld else { return false }
            if event.isDown { held.append(event.usage) } else { held.removeAll { $0 == event.usage } }
            return true
        }
        let end = transitions.last?.time ?? .zero
        return transitions + held.map { RecordedKeyEvent(usage: $0, isDown: false, time: end) }
    }

    private static func macroEvent(of event: RecordedKeyEvent) -> MacroEvent {
        event.isDown ? .keyDown(usage: event.usage) : .keyUp(usage: event.usage)
    }

    /// The firmware stores a delay in 16 bits, so longer pauses play back as the longest it can.
    private static func milliseconds(from start: Duration, to end: Duration) -> UInt16 {
        let gap = (end - start).components
        let milliseconds = gap.seconds * 1000 + gap.attoseconds / 1_000_000_000_000_000
        return UInt16(clamping: milliseconds)
    }
}
