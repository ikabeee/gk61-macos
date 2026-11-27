import AppKit
import GK61Core
import SwiftUI

extension PaletteColor {
    var name: String {
        switch self {
        case .red: "Red"
        case .green: "Green"
        case .blue: "Blue"
        case .yellow: "Yellow"
        case .magenta: "Magenta"
        case .cyan: "Cyan"
        case .white: "White"
        }
    }

    var swatch: Color {
        switch self {
        case .red: Color(red: 1, green: 0, blue: 0)
        case .green: Color(red: 0, green: 1, blue: 0)
        case .blue: Color(red: 0, green: 0, blue: 1)
        case .yellow: Color(red: 1, green: 1, blue: 0)
        case .magenta: Color(red: 1, green: 0, blue: 1)
        case .cyan: Color(red: 0, green: 1, blue: 1)
        case .white: Color(red: 1, green: 1, blue: 1)
        }
    }
}

extension GK61Core.RGBColor {
    init(_ color: Color) {
        let srgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(
            red: Self.channel(srgb.redComponent),
            green: Self.channel(srgb.greenComponent),
            blue: Self.channel(srgb.blueComponent))
    }

    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    /// Picks dark text on bright keys (Rec. 709 luma).
    var isLight: Bool {
        0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue) > 140
    }

    private static func channel(_ component: CGFloat) -> UInt8 {
        UInt8((min(max(component, 0), 1) * 255).rounded())
    }
}
