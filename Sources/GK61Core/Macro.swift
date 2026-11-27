/// A recorded sequence the keyboard plays back by itself when a macro key is pressed.
public struct Macro: Hashable, Sendable {
    public let playback: MacroPlayback
    public let steps: [MacroStep]

    /// Throws when the encoded body would not fit the firmware's macro buffer.
    public init(playback: MacroPlayback, steps: [MacroStep]) throws(MacroError) {
        let byteCount = MacroBody.encode(steps).count
        guard byteCount <= MacroBody.capacity else { throw .bodyTooLong(byteCount: byteCount) }
        self.playback = playback
        self.steps = steps
    }

    /// The bytes uploaded to the macro buffer (layout in docs/protocol.md, "Macro body").
    public var body: [UInt8] {
        MacroBody.encode(steps)
    }
}

public enum MacroError: Error, Equatable {
    case bodyTooLong(byteCount: Int)
}

/// How the firmware repeats a macro while its key is used.
public enum MacroPlayback: Hashable, Sendable {
    /// Plays the macro this many times per key press.
    case repeatCount(UInt16)
    /// Repeats the macro while the key is held.
    case untilReleased
    /// Starts repeating on one press and stops on the next.
    case untilPressedAgain

    /// Key-matrix code bytes for a key playing a macro from buffer `bufferID` (fcn.004082c0, type 5).
    func keyEntry(bufferID: UInt8) -> [UInt8] {
        switch self {
        case let .repeatCount(count): [0xF3, bufferID] + count.bigEndianBytes
        case .untilReleased: [0xF0, bufferID, 0x00, 0x00]
        case .untilPressedAgain: [0xF1, bufferID, 0x00, 0x00]
        }
    }
}

/// One event of a macro and the pause the firmware waits after it.
public struct MacroStep: Hashable, Sendable {
    public let event: MacroEvent
    public let delayMilliseconds: UInt16

    public init(_ event: MacroEvent, delayMilliseconds: UInt16 = 0) {
        self.event = event
        self.delayMilliseconds = delayMilliseconds
    }

    var bytes: [UInt8] {
        event.bytes + delayBytes
    }

    private var delayBytes: [UInt8] {
        guard delayMilliseconds > 0 else { return [] }
        return [0x01] + delayMilliseconds.bigEndianBytes
    }
}

public enum MacroEvent: Hashable, Sendable {
    /// HID keyboard usage; modifiers are usages E0–E7.
    case keyDown(usage: UInt8)
    case keyUp(usage: UInt8)
    case mouseDown(MouseButton)
    case mouseUp(MouseButton)
    case wheel(WheelDirection, notches: UInt16)

    var bytes: [UInt8] {
        switch self {
        case let .keyDown(usage): [0x02, usage]
        case let .keyUp(usage): [0x03, usage]
        case let .mouseDown(button): [0x04, button.rawValue]
        case let .mouseUp(button): [0x05, button.rawValue]
        case let .wheel(direction, notches): (0..<notches).flatMap { _ in [direction.rawValue, 0x00] }
        }
    }
}

public enum MouseButton: UInt8, Hashable, Sendable {
    case left = 1
    case right = 2
    case middle = 3
}

public enum WheelDirection: UInt8, Hashable, Sendable {
    case up = 0x08
    case down = 0x09
}

enum MacroBody {
    /// The Windows driver serializes into a 512-byte buffer and never checks the bound.
    static let capacity = 512

    /// `01` then 30 reserved zero bytes; events start at byte 31.
    static let header: [UInt8] = [0x01] + Array(repeating: 0, count: 30)

    static func encode(_ steps: [MacroStep]) -> [UInt8] {
        header + steps.flatMap(\.bytes)
    }
}

extension UInt16 {
    /// The firmware stores every 16-bit macro field high byte first.
    var bigEndianBytes: [UInt8] {
        [UInt8(self >> 8), UInt8(self & 0xFF)]
    }
}
