import Foundation
import GK61Core

/// What this Mac last wrote to the keyboard. The firmware has no read-back command,
/// so this file is the only record of the keyboard's configuration.
struct AppliedConfiguration: Equatable {
    var keyActions: [Int: KeyAction]
    var lighting: Lighting?
    var appliedAt: Date?

    static let nothingApplied = AppliedConfiguration(keyActions: [:], lighting: nil, appliedAt: nil)
}

/// JSON file in Application Support that keeps the last applied configuration across launches.
struct ConfigurationFile: Sendable {
    let url: URL

    static let standard = ConfigurationFile(
        url: .applicationSupportDirectory.appending(path: "GK61/last-applied.json"))

    func load() throws -> AppliedConfiguration {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return .nothingApplied
        }
        return try Self.decoder.decode(SavedConfiguration.self, from: Data(contentsOf: url)).applied()
    }

    func save(_ configuration: AppliedConfiguration) throws {
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

enum SavedConfigurationError: LocalizedError {
    case unknownLightingMode(UInt8)
    case unknownPaletteColor(UInt8)

    var errorDescription: String? {
        switch self {
        case let .unknownLightingMode(number): "Unknown lighting mode \(number)."
        case let .unknownPaletteColor(index): "Unknown palette color \(index)."
        }
    }
}

// MARK: - File format

/// On-disk shape, kept apart from the core types so the core stays free of persistence concerns.
private struct SavedConfiguration: Codable {
    var keyActions: [Int: SavedKeyAction]
    var lighting: SavedLighting?
    var appliedAt: Date?

    init(_ configuration: AppliedConfiguration) {
        keyActions = configuration.keyActions.mapValues(SavedKeyAction.init)
        lighting = configuration.lighting.map(SavedLighting.init)
        appliedAt = configuration.appliedAt
    }

    func applied() throws -> AppliedConfiguration {
        AppliedConfiguration(
            keyActions: keyActions.mapValues(\.keyAction),
            lighting: try lighting?.lighting(),
            appliedAt: appliedAt)
    }
}

private struct SavedKeyAction: Codable {
    var modifiers: UInt8
    var usage: UInt8
    var secondUsage: UInt8

    init(_ action: KeyAction) {
        modifiers = action.modifiers.rawValue
        usage = action.usage
        secondUsage = action.secondUsage
    }

    var keyAction: KeyAction {
        .keys(modifiers: ModifierMask(rawValue: modifiers), usage: usage, secondUsage: secondUsage)
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
