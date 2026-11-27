/// A backlight setting as the firmware takes it. Speed and brightness are levels 0…4.
public struct Lighting: Hashable, Sendable {
    public var mode: LightingMode
    public var speed: UInt8
    public var brightness: UInt8
    public var color: LightingColor

    public init(mode: LightingMode, speed: UInt8, brightness: UInt8, color: LightingColor) {
        self.mode = mode
        self.speed = speed
        self.brightness = brightness
        self.color = color
    }
}

public enum LightingColor: Hashable, Sendable {
    case rainbow
    case palette(PaletteColor)
    /// Custom modes only: color per key-matrix slot; missing slots stay dark.
    case perKey([Int: RGBColor])
}

public struct RGBColor: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let black = RGBColor(red: 0, green: 0, blue: 0)
}

/// The firmware's fixed palette, in wire order.
public enum PaletteColor: UInt8, CaseIterable, Sendable {
    case red, green, blue, yellow, magenta, cyan, white
}

public struct LightingMode: Hashable, Sendable, Identifiable {
    /// How the mode reads the color byte (Cfg `LedOptN` field 4).
    public enum ColorStyle: Hashable, Sendable {
        /// Color is ignored (field 0).
        case none
        /// Palette only; the byte is the palette index (field 7).
        case palette
        /// Rainbow or palette; the byte is 0 for rainbow, else palette index + 1 (field 8).
        case paletteOrRainbow
        /// Per-key RGB sent after the header; the byte is FF (field 0xFF).
        case perKey
    }

    public let number: UInt8
    public let name: String
    public let hasSpeed: Bool
    public let colorStyle: ColorStyle

    public var id: UInt8 { number }

    public static func named(_ name: String) -> LightingMode? {
        all.first { $0.name == name }
    }

    /// Modes 1–31 of the `00F7-2` Cfg, with names from its text.xml.
    public static let all: [LightingMode] = [
        LightingMode(number: 0x01, name: "Off", hasSpeed: false, colorStyle: .none),
        LightingMode(number: 0x02, name: "Vortex", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x03, name: "Surfing right", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x04, name: "Lighting by press", hasSpeed: true, colorStyle: .paletteOrRainbow),
        LightingMode(number: 0x05, name: "Breath", hasSpeed: true, colorStyle: .paletteOrRainbow),
        LightingMode(number: 0x06, name: "Ripple", hasSpeed: true, colorStyle: .paletteOrRainbow),
        LightingMode(number: 0x07, name: "Always lighting", hasSpeed: false, colorStyle: .palette),
        LightingMode(number: 0x08, name: "Wave spectrum", hasSpeed: true, colorStyle: .paletteOrRainbow),
        LightingMode(number: 0x09, name: "Center surfing", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x0A, name: "Snake marquee middle", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x0B, name: "Glowing fish", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x0C, name: "Heart-shaped", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x0D, name: "Colorful fountain", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x0E, name: "Traffic", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x0F, name: "Gluttonous snake", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x10, name: "Wild dance", hasSpeed: true, colorStyle: .paletteOrRainbow),
        LightingMode(number: 0x11, name: "Surfing cross", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x12, name: "Spectrum", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x13, name: "Random fountain", hasSpeed: true, colorStyle: .none),
        LightingMode(number: 0x14, name: "Game mode 1", hasSpeed: false, colorStyle: .palette),
        LightingMode(number: 0x15, name: "Game mode 2", hasSpeed: false, colorStyle: .palette),
        LightingMode(number: 0x16, name: "Game mode 3", hasSpeed: false, colorStyle: .palette),
        LightingMode(number: 0x17, name: "Game mode 4", hasSpeed: false, colorStyle: .palette),
        LightingMode(number: 0x18, name: "Game mode 5", hasSpeed: false, colorStyle: .palette),
    ] + (1...7).map { custom in
        LightingMode(number: 0x18 + UInt8(custom), name: "Custom mode \(custom)", hasSpeed: false, colorStyle: .perKey)
    }
}

extension Packet {
    /// SetLED. Custom modes repeat the header on every packet and carry 13 per-key entries each.
    public static func lighting(_ lighting: Lighting) -> [Packet] {
        let header: [UInt8] = [0xAE, 0x01, 0x00, 0x00, lighting.mode.number, lighting.speed, lighting.brightness]
        guard case let .perKey(colors) = lighting.color, lighting.mode.colorStyle == .perKey else {
            return [Packet(header + [colorByte(of: lighting)])]
        }
        let entries = perKeyEntries(colors)
        return stride(from: 0, to: entries.count, by: PerKeyLighting.bytesPerPacket).map { offset in
            Packet(header + [0xFF] + entries[offset..<min(offset + PerKeyLighting.bytesPerPacket, entries.count)])
        }
    }

    private static func colorByte(of lighting: Lighting) -> UInt8 {
        switch (lighting.mode.colorStyle, lighting.color) {
        case let (.palette, .palette(color)): color.rawValue
        case let (.paletteOrRainbow, .palette(color)): color.rawValue + 1
        case (.perKey, _): 0xFF
        case (.none, _), (.palette, _), (.paletteOrRainbow, _): 0
        }
    }

    /// Every matrix slot as `[slot | 0x80, R, G, B]`, then an FF terminator.
    private static func perKeyEntries(_ colors: [Int: RGBColor]) -> [UInt8] {
        let entries = (0..<KeyMatrix.slotCount).flatMap { slot in
            let color = colors[slot] ?? .black
            return [UInt8(slot) | 0x80, color.red, color.green, color.blue]
        }
        return entries + [0xFF]
    }
}

enum PerKeyLighting {
    static let bytesPerPacket = 52
}
