import GK61Core

/// How a macro step reads in the step list, such as "Press ⌘ Left Command".
enum MacroStepText {
    static func describe(_ event: MacroEvent) -> String {
        switch event {
        case let .keyDown(usage): "Press \(keyName(usage))"
        case let .keyUp(usage): "Release \(keyName(usage))"
        case let .mouseDown(button): "Press \(buttonName(button)) mouse button"
        case let .mouseUp(button): "Release \(buttonName(button)) mouse button"
        case let .wheel(direction, notches): "Scroll \(direction == .up ? "up" : "down") \(notches)×"
        }
    }

    static func systemImage(for event: MacroEvent) -> String {
        switch event {
        case .keyDown, .mouseDown: "arrow.down.circle"
        case .keyUp, .mouseUp: "arrow.up.circle"
        case .wheel: "scroll"
        }
    }

    private static func keyName(_ usage: UInt8) -> String {
        guard let key = KeyUsage.named(usage) else { return "key 0x" + String(usage, radix: 16, uppercase: true) }
        return key.symbol == key.name ? key.name : "\(key.symbol) \(key.name)"
    }

    private static func buttonName(_ button: MouseButton) -> String {
        switch button {
        case .left: "left"
        case .right: "right"
        case .middle: "middle"
        }
    }
}

/// How a key repeats its macro, as the inspector offers it.
enum PlaybackChoice: String, CaseIterable, Identifiable {
    case times = "A number of times"
    case whileHeld = "While held"
    case untilPressedAgain = "Until pressed again"

    var id: Self { self }

    init(_ playback: MacroPlayback) {
        switch playback {
        case .repeatCount: self = .times
        case .untilReleased: self = .whileHeld
        case .untilPressedAgain: self = .untilPressedAgain
        }
    }

    var help: String {
        switch self {
        case .times: "Each press plays the macro the number of times you set"
        case .whileHeld: "The macro repeats for as long as you hold the key"
        case .untilPressedAgain: "One press starts repeating the macro; the next press stops it"
        }
    }
}

extension PlaybackChoice {
    /// Switching to "A number of times" keeps the count the key already had, or plays once.
    func playback(replacing current: MacroPlayback) -> MacroPlayback {
        switch (self, current) {
        case (.times, .repeatCount): current
        case (.times, _): .repeatCount(1)
        case (.whileHeld, _): .untilReleased
        case (.untilPressedAgain, _): .untilPressedAgain
        }
    }
}
