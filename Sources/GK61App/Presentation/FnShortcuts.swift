/// What the keyboard does with Fn held, as shipped. Decoded from the Windows driver's factory Fn table
/// (Cfg.ini [FN]) and its keycap legends (skins/keyimg.png). The app writes zeros for these keys, which
/// keeps the firmware's own Fn function.
struct FnShortcut: Identifiable {
    enum Group: String, CaseIterable, Identifiable {
        case media = "Media"
        case functionKeys = "Function Keys"
        case navigation = "Navigation and Editing"
        case arrows = "Arrows"
        case keyboard = "Keyboard"

        var id: Self { self }
    }

    /// HID usage of the key you press together with Fn.
    let usage: UInt8
    /// Short text drawn on the keycap.
    let legend: String
    let name: String
    let group: Group
    /// A caveat, such as a function the driver doesn't name.
    var note: String?

    var id: UInt8 { usage }
}

extension FnShortcut {
    static func factory(includingArrowToggle: Bool) -> [FnShortcut] {
        includingArrowToggle ? factoryLayer + [arrowToggle] : factoryLayer
    }

    private static let arrowToggle = FnShortcut(
        usage: 0x28, legend: "⇅", name: "Arrow mode on or off", group: .arrows,
        note: "Added by this app; works while GK61 is running")

    private static let factoryLayer: [FnShortcut] = media + functionKeys + navigation + arrows + keyboard

    private static let media: [FnShortcut] = [
        FnShortcut(usage: 0x04, legend: "⏯", name: "Play / Pause", group: .media),
        FnShortcut(usage: 0x16, legend: "⏮", name: "Previous track", group: .media),
        FnShortcut(usage: 0x07, legend: "⏭", name: "Next track", group: .media),
        FnShortcut(usage: 0x09, legend: "Mute", name: "Mute", group: .media),
        FnShortcut(usage: 0x0A, legend: "Vol−", name: "Volume down", group: .media),
        FnShortcut(usage: 0x0B, legend: "Vol+", name: "Volume up", group: .media),
    ]

    private static let functionKeys: [FnShortcut] = zip(functionKeyUsages, 1...).map { usage, number in
        FnShortcut(usage: usage, legend: "F\(number)", name: "F\(number)", group: .functionKeys)
    }

    /// 1 through 0, then - and =.
    private static let functionKeyUsages: [UInt8] = Array(0x1E...0x27) + [0x2D, 0x2E]

    private static let navigation: [FnShortcut] = [
        FnShortcut(usage: 0x29, legend: "`", name: "` and ~", group: .navigation),
        FnShortcut(usage: 0x1C, legend: "PrtSc", name: "Print Screen", group: .navigation, note: "macOS reads it as F13"),
        FnShortcut(usage: 0x18, legend: "ScrLk", name: "Scroll Lock", group: .navigation, note: "macOS reads it as F14"),
        FnShortcut(usage: 0x0C, legend: "Pause", name: "Pause", group: .navigation, note: "macOS reads it as F15"),
        FnShortcut(usage: 0x0D, legend: "Ins", name: "Insert", group: .navigation, note: "macOS reads it as Help"),
        FnShortcut(usage: 0x0E, legend: "Home", name: "Home", group: .navigation),
        FnShortcut(usage: 0x0F, legend: "PgUp", name: "Page Up", group: .navigation),
        FnShortcut(usage: 0x10, legend: "Del", name: "Forward Delete", group: .navigation),
        FnShortcut(usage: 0x36, legend: "End", name: "End", group: .navigation),
        FnShortcut(usage: 0x37, legend: "PgDn", name: "Page Down", group: .navigation),
    ]

    private static let arrows: [FnShortcut] = [
        FnShortcut(usage: 0x38, legend: "↑", name: "Up", group: .arrows),
        FnShortcut(usage: 0xE6, legend: "←", name: "Left", group: .arrows),
        FnShortcut(usage: 0x65, legend: "↓", name: "Down", group: .arrows),
        FnShortcut(usage: 0xE4, legend: "→", name: "Right", group: .arrows),
    ]

    private static let unnamedLighting = "Changes the backlight; the driver doesn't name which setting"
    private static let onboardMacro = "Keycap legend; not tested on this keyboard"

    private static let keyboard: [FnShortcut] = [
        FnShortcut(usage: 0xE3, legend: "🔒", name: "Lock the Command (Windows) key", group: .keyboard),
        FnShortcut(usage: 0x2B, legend: "●", name: "Record an onboard macro", group: .keyboard, note: onboardMacro),
        FnShortcut(usage: 0x14, legend: "M1", name: "Onboard macro 1", group: .keyboard, note: onboardMacro),
        FnShortcut(usage: 0x1A, legend: "M2", name: "Onboard macro 2", group: .keyboard, note: onboardMacro),
        FnShortcut(usage: 0x08, legend: "M3", name: "Onboard macro 3", group: .keyboard, note: onboardMacro),
    ] + lightingUsages.map { usage in
        FnShortcut(usage: usage, legend: "☀", name: "Lighting", group: .keyboard, note: unnamedLighting)
    }

    /// O, P, [, ], \, ; and '.
    private static let lightingUsages: [UInt8] = [0x12, 0x13, 0x2F, 0x30, 0x31, 0x33, 0x34]
}
