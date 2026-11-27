/// A mode switched from the keyboard. Its Fn key sends a key no Mac app uses; the app hears it, changes
/// the keys on the Mac when the firmware can't, and lights the affected keys.
public enum KeyboardToggle: String, CaseIterable, Sendable {
    /// Fn+Enter: the keys under the right Shift become arrows.
    case arrowMode
    /// Fn+Left Win: the firmware's own Win lock, which still runs when Fn+Left Win sends F23. The keyboard
    /// stops sending Left Win (Command on a Mac); the app only lights the key.
    case commandLock

    /// The key pressed together with Fn.
    public var fnKeyUsage: UInt8 {
        switch self {
        case .arrowMode: 0x28
        case .commandLock: Self.leftWinUsage
        }
    }

    /// What the Fn key sends: F24 or F23.
    public var signalUsage: UInt8 {
        switch self {
        case .arrowMode: 0x73
        case .commandLock: 0x72
        }
    }

    /// The Mac-side key mapping while the toggle is on. Cmd lock has none: a second lock on the Mac would
    /// fall out of step with the firmware's whenever the app missed a press, and then block Command for good.
    public var macMapping: [UInt8: UInt8] {
        switch self {
        case .arrowMode: ArrowMode.swappedUsages
        case .commandLock: [:]
        }
    }

    public init?(signalUsage: UInt8) {
        guard let toggle = Self.allCases.first(where: { $0.signalUsage == signalUsage }) else { return nil }
        self = toggle
    }

    /// The Fn-layer actions that make every toggle's Fn key send its signal.
    public static func fnActions(for layout: KeyLayout) -> [Int: KeyAction] {
        Dictionary(uniqueKeysWithValues: allCases.compactMap { toggle in
            layout.key(withUsage: toggle.fnKeyUsage).map { ($0.matrixIndex, KeyAction.remap(toUsage: toggle.signalUsage)) }
        })
    }

    /// The Mac-side mapping for the toggles that are on.
    public static func macMapping(for toggles: Set<KeyboardToggle>) -> [UInt8: UInt8] {
        toggles.reduce(into: [:]) { mapping, toggle in mapping.merge(toggle.macMapping) { current, _ in current } }
    }

    /// What the keyboard shows while toggles are on: their keys lit, the rest dark. The firmware has no
    /// temporary LED command, so this is a saved custom mode; the last slot leaves custom modes 1–6 to the user.
    public static func lighting(for layout: KeyLayout, showing toggles: Set<KeyboardToggle>) -> Lighting {
        let colors = toggles.reduce(into: [Int: RGBColor]()) { colors, toggle in
            for usage in toggle.litUsages {
                if let key = layout.key(withUsage: usage) { colors[key.matrixIndex] = toggle.lightColor }
            }
        }
        return Lighting(mode: lightingMode, speed: 0, brightness: 4, color: .perKey(colors))
    }

    private var litUsages: [UInt8] {
        switch self {
        case .arrowMode: Array(ArrowMode.arrowUsages.keys)
        case .commandLock: [Self.leftWinUsage]
        }
    }

    private var lightColor: RGBColor {
        switch self {
        case .arrowMode: .white
        case .commandLock: RGBColor(red: 0xFF, green: 0, blue: 0)
        }
    }

    private static let leftWinUsage: UInt8 = 0xE3
    private static let lightingMode = LightingMode.custom(LightingMode.customModeCount)
}

extension KeyLayout {
    public func key(withUsage usage: UInt8) -> Key? {
        keys.first { $0.defaultUsage == usage }
    }
}
