import Foundation
import GK61Core

/// What this Mac last wrote to the keyboard. The firmware has no read-back command,
/// so this file is the only record of the keyboard's configuration.
public struct AppliedConfiguration: Equatable, Sendable {
    public var keyActions: [Int: KeyAction]
    /// The library macro each macro key was copied from, by matrix index.
    public var macroSources: [Int: UUID]
    /// What keys send while Fn is held; keys without an entry keep their factory Fn function.
    public var fnKeyActions: [Int: KeyAction]
    public var lighting: Lighting?
    public var appliedAt: Date?

    public init(
        keyActions: [Int: KeyAction], macroSources: [Int: UUID] = [:], fnKeyActions: [Int: KeyAction] = [:],
        lighting: Lighting?, appliedAt: Date?
    ) {
        self.keyActions = keyActions
        self.macroSources = macroSources
        self.fnKeyActions = fnKeyActions
        self.lighting = lighting
        self.appliedAt = appliedAt
    }

    public static let nothingApplied = AppliedConfiguration(keyActions: [:], lighting: nil, appliedAt: nil)
}

/// JSON file in Application Support that keeps the last applied configuration across launches.
public struct ConfigurationFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static let standard = ConfigurationFile(
        url: .applicationSupportDirectory.appending(path: "GK61/last-applied.json"))

    public func load() throws -> AppliedConfiguration {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return .nothingApplied
        }
        return try Self.decoder.decode(SavedConfiguration.self, from: Data(contentsOf: url)).applied()
    }

    public func save(_ configuration: AppliedConfiguration) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(SavedConfiguration(configuration)).write(to: url, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

public enum SavedConfigurationError: LocalizedError {
    case unknownLightingMode(UInt8)
    case unknownPaletteColor(UInt8)
    case unknownMouseButton(UInt8)
    case unknownWheelDirection(UInt8)

    public var errorDescription: String? {
        switch self {
        case let .unknownLightingMode(number): "Unknown lighting mode \(number)."
        case let .unknownPaletteColor(index): "Unknown palette color \(index)."
        case let .unknownMouseButton(button): "Unknown mouse button \(button)."
        case let .unknownWheelDirection(direction): "Unknown wheel direction \(direction)."
        }
    }
}

// MARK: - File format

/// On-disk shape, kept apart from the core types so the core stays free of persistence concerns.
private struct SavedConfiguration: Codable {
    var keyActions: [Int: SavedKeyAction]
    /// Absent in files saved before macros existed.
    var macroSources: [Int: UUID]?
    /// Absent in files saved before the Fn layer was written.
    var fnKeyActions: [Int: SavedKeyAction]?
    var lighting: SavedLighting?
    var appliedAt: Date?

    init(_ configuration: AppliedConfiguration) {
        keyActions = configuration.keyActions.mapValues(SavedKeyAction.init)
        macroSources = configuration.macroSources
        fnKeyActions = configuration.fnKeyActions.mapValues(SavedKeyAction.init)
        lighting = configuration.lighting.map(SavedLighting.init)
        appliedAt = configuration.appliedAt
    }

    func applied() throws -> AppliedConfiguration {
        AppliedConfiguration(
            keyActions: try keyActions.mapValues { try $0.keyAction() },
            macroSources: macroSources ?? [:],
            fnKeyActions: try (fnKeyActions ?? [:]).mapValues { try $0.keyAction() },
            lighting: try lighting?.lighting(),
            appliedAt: appliedAt)
    }
}

/// A plain key keeps the original `{modifiers, usage, secondUsage}` shape; a macro key is `{"macro": …}`.
private enum SavedKeyAction: Codable {
    case keys(SavedKeys)
    case macro(SavedMacro)

    private enum CodingKeys: String, CodingKey {
        case macro
    }

    init(_ action: KeyAction) {
        switch action {
        case let .keys(modifiers, usage, secondUsage):
            self = .keys(SavedKeys(modifiers: modifiers.rawValue, usage: usage, secondUsage: secondUsage))
        case let .macro(macro):
            self = .macro(SavedMacro(macro))
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let macro = try container.decodeIfPresent(SavedMacro.self, forKey: .macro) {
            self = .macro(macro)
        } else {
            self = .keys(try SavedKeys(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .keys(keys):
            try keys.encode(to: encoder)
        case let .macro(macro):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(macro, forKey: .macro)
        }
    }

    func keyAction() throws -> KeyAction {
        switch self {
        case let .keys(keys):
            .keys(modifiers: ModifierMask(rawValue: keys.modifiers), usage: keys.usage, secondUsage: keys.secondUsage)
        case let .macro(macro):
            .macro(try macro.macro())
        }
    }
}

private struct SavedKeys: Codable {
    var modifiers: UInt8
    var usage: UInt8
    var secondUsage: UInt8
}

struct SavedMacro: Codable {
    var playback: SavedPlayback
    var steps: [SavedMacroStep]

    init(_ macro: Macro) {
        playback = SavedPlayback(macro.playback)
        steps = macro.steps.map(SavedMacroStep.init)
    }

    func macro() throws -> Macro {
        try Macro(playback: playback.playback, steps: try steps.map { try $0.step() })
    }
}

enum SavedPlayback: Codable {
    case repeatCount(UInt16)
    case untilReleased
    case untilPressedAgain

    init(_ playback: MacroPlayback) {
        switch playback {
        case let .repeatCount(count): self = .repeatCount(count)
        case .untilReleased: self = .untilReleased
        case .untilPressedAgain: self = .untilPressedAgain
        }
    }

    var playback: MacroPlayback {
        switch self {
        case let .repeatCount(count): .repeatCount(count)
        case .untilReleased: .untilReleased
        case .untilPressedAgain: .untilPressedAgain
        }
    }
}

struct SavedMacroStep: Codable {
    var event: SavedMacroEvent
    var delayMilliseconds: UInt16

    init(_ step: MacroStep) {
        event = SavedMacroEvent(step.event)
        delayMilliseconds = step.delayMilliseconds
    }

    func step() throws -> MacroStep {
        MacroStep(try event.event(), delayMilliseconds: delayMilliseconds)
    }
}

enum SavedMacroEvent: Codable {
    case keyDown(usage: UInt8)
    case keyUp(usage: UInt8)
    case mouseDown(button: UInt8)
    case mouseUp(button: UInt8)
    case wheel(direction: UInt8, notches: UInt16)

    init(_ event: MacroEvent) {
        switch event {
        case let .keyDown(usage): self = .keyDown(usage: usage)
        case let .keyUp(usage): self = .keyUp(usage: usage)
        case let .mouseDown(button): self = .mouseDown(button: button.rawValue)
        case let .mouseUp(button): self = .mouseUp(button: button.rawValue)
        case let .wheel(direction, notches): self = .wheel(direction: direction.rawValue, notches: notches)
        }
    }

    func event() throws -> MacroEvent {
        switch self {
        case let .keyDown(usage): .keyDown(usage: usage)
        case let .keyUp(usage): .keyUp(usage: usage)
        case let .mouseDown(button): .mouseDown(try Self.mouseButton(button))
        case let .mouseUp(button): .mouseUp(try Self.mouseButton(button))
        case let .wheel(direction, notches): .wheel(try Self.wheelDirection(direction), notches: notches)
        }
    }

    private static func mouseButton(_ rawValue: UInt8) throws -> MouseButton {
        guard let button = MouseButton(rawValue: rawValue) else { throw SavedConfigurationError.unknownMouseButton(rawValue) }
        return button
    }

    private static func wheelDirection(_ rawValue: UInt8) throws -> WheelDirection {
        guard let direction = WheelDirection(rawValue: rawValue) else { throw SavedConfigurationError.unknownWheelDirection(rawValue) }
        return direction
    }
}

private struct SavedLighting: Codable {
    var mode: UInt8
    var speed: UInt8
    var brightness: UInt8
    var color: SavedLightingColor

    init(_ lighting: Lighting) {
        mode = lighting.mode.number
        speed = lighting.speed
        brightness = lighting.brightness
        color = SavedLightingColor(lighting.color)
    }

    func lighting() throws -> Lighting {
        guard let lightingMode = LightingMode.all.first(where: { $0.number == mode }) else {
            throw SavedConfigurationError.unknownLightingMode(mode)
        }
        return Lighting(mode: lightingMode, speed: speed, brightness: brightness, color: try color.lightingColor())
    }
}

private enum SavedLightingColor: Codable {
    case rainbow
    case palette(UInt8)
    case perKey([Int: SavedRGB])

    init(_ color: LightingColor) {
        switch color {
        case .rainbow: self = .rainbow
        case let .palette(paletteColor): self = .palette(paletteColor.rawValue)
        case let .perKey(colors): self = .perKey(colors.mapValues(SavedRGB.init))
        }
    }

    func lightingColor() throws -> LightingColor {
        switch self {
        case .rainbow:
            return .rainbow
        case let .palette(index):
            guard let paletteColor = PaletteColor(rawValue: index) else {
                throw SavedConfigurationError.unknownPaletteColor(index)
            }
            return .palette(paletteColor)
        case let .perKey(colors):
            return .perKey(colors.mapValues(\.rgbColor))
        }
    }
}

private struct SavedRGB: Codable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8

    init(_ color: RGBColor) {
        red = color.red
        green = color.green
        blue = color.blue
    }

    var rgbColor: RGBColor { RGBColor(red: red, green: green, blue: blue) }
}
