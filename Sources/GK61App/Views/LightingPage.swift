import GK61Core
import SwiftUI

/// The lighting edits a page can request; the store performs them.
struct LightingEditingActions {
    let selectMode: (LightingMode) -> Void
    let setSpeed: (UInt8) -> Void
    let setBrightness: (UInt8) -> Void
    let setColor: (LightingColor) -> Void
    let paintKey: (KeyLayout.Key, GK61Core.RGBColor) -> Void
    let paintAllKeys: (GK61Core.RGBColor) -> Void
}

struct LightingPage: View {
    let lighting: Lighting
    let keys: [KeyLayout.Key]
    let hasEverApplied: Bool
    let editing: LightingEditingActions

    var body: some View {
        Form {
            effectSection
            colorSection
            if lighting.mode.colorStyle == .perKey {
                PerKeyPainter(keys: keys, colors: perKeyColors, editing: editing)
            }
            Section {
                Text(provenanceNote).font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Lighting")
    }

    private var effectSection: some View {
        Section("Effect") {
            Picker("Mode", selection: Binding { lighting.mode } set: { editing.selectMode($0) }) {
                ForEach(LightingMode.all) { mode in
                    Text(mode.name).tag(mode)
                }
            }
            if lighting.mode.hasSpeed {
                LevelSlider(
                    title: "Speed", level: lighting.speed, onChange: editing.setSpeed,
                    minimumSymbol: "tortoise", maximumSymbol: "hare")
            }
            LevelSlider(
                title: "Brightness", level: lighting.brightness, onChange: editing.setBrightness,
                minimumSymbol: "sun.min", maximumSymbol: "sun.max")
        }
    }

    @ViewBuilder
    private var colorSection: some View {
        switch lighting.mode.colorStyle {
        case .none:
            Section("Color") {
                Text("This effect uses its own colors.").foregroundStyle(.secondary)
            }
        case .palette:
            Section("Color") {
                PaletteSwatches(color: lighting.color, offersRainbow: false, onSelect: editing.setColor)
            }
        case .paletteOrRainbow:
            Section("Color") {
                PaletteSwatches(color: lighting.color, offersRainbow: true, onSelect: editing.setColor)
            }
        case .perKey:
            EmptyView()
        }
    }

    private var perKeyColors: [Int: GK61Core.RGBColor] {
        guard case let .perKey(colors) = lighting.color else { return [:] }
        return colors
    }

    private var provenanceNote: String {
        let source = hasEverApplied
            ? "These settings start from the last lighting applied from this Mac."
            : "Lighting hasn't been applied from this Mac yet, so these are suggested starting values."
        return source + " The keyboard can't report its current lighting, so changes made with other software or the Fn shortcuts don't show here."
    }
}

/// A five-step level (0…4) as a slider with symbols at both ends.
private struct LevelSlider: View {
    let title: String
    let level: UInt8
    let onChange: (UInt8) -> Void
    let minimumSymbol: String
    let maximumSymbol: String

    var body: some View {
        Slider(value: value, in: 0...Double(ConfiguratorStore.maximumLevel), step: 1) {
            Text(title)
        } minimumValueLabel: {
            Image(systemName: minimumSymbol).accessibilityLabel("Lowest")
        } maximumValueLabel: {
            Image(systemName: maximumSymbol).accessibilityLabel("Highest")
        }
        .accessibilityValue("Level \(Int(level) + 1) of \(Int(ConfiguratorStore.maximumLevel) + 1)")
    }

    private var value: Binding<Double> {
        Binding { Double(level) } set: { onChange(UInt8($0.rounded())) }
    }
}

private struct PaletteSwatches: View {
    let color: LightingColor
    let offersRainbow: Bool
    let onSelect: (LightingColor) -> Void

    var body: some View {
        HStack(spacing: 10) {
            if offersRainbow {
                swatch(.rainbow, name: "Rainbow", fill: AnyShapeStyle(Self.rainbow))
            }
            ForEach(PaletteColor.allCases, id: \.self) { paletteColor in
                swatch(.palette(paletteColor), name: paletteColor.name, fill: AnyShapeStyle(paletteColor.swatch))
            }
        }
        .padding(.vertical, 4)
    }

    private func swatch(_ option: LightingColor, name: String, fill: AnyShapeStyle) -> some View {
        let isSelected = option == color
        return Button { onSelect(option) } label: {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(.separator))
                .frame(width: 24, height: 24)
                .padding(3)
                .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static let rainbow = AngularGradient(
        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center)
}

/// Custom modes: pick a brush color and click keys to paint them.
private struct PerKeyPainter: View {
    let keys: [KeyLayout.Key]
    let colors: [Int: GK61Core.RGBColor]
    let editing: LightingEditingActions
    @State private var brush = Color.white

    var body: some View {
        Section("Key Colors") {
            HStack {
                ColorPicker("Brush", selection: $brush, supportsOpacity: false)
                Spacer()
                Button("Paint All Keys") { editing.paintAllKeys(GK61Core.RGBColor(brush)) }
                Button("Turn All Off") { editing.paintAllKeys(.black) }
            }
            Text("Click a key to paint it with the brush color. Black keys stay unlit.")
                .font(.callout)
                .foregroundStyle(.secondary)
            KeyboardView(keys: keys, selectedKeyID: nil, appearance: appearance(of:)) { key in
                editing.paintKey(key, GK61Core.RGBColor(brush))
            }
            .padding(.vertical, 8)
        }
    }

    private func appearance(of key: KeyLayout.Key) -> KeyCapAppearance {
        let color = colors[key.id] ?? .black
        return KeyCapAppearance(
            caption: key.label,
            fill: color.color,
            foreground: color.isLight ? .black : .white,
            help: "Paint \(key.label)")
    }
}
