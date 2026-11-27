/// Arrow mode, like the RK61's Fn+Enter: the keys under the right Shift become arrow keys until toggled
/// back. The GK61 firmware has no such layer, so Fn+Enter sends F24 and the app swaps the keys on the Mac.
public enum ArrowMode {
    /// HID usage F24: no Mac app uses it, so it is free to signal the toggle.
    public static let toggleUsage: UInt8 = 0x73

    /// Each key's HID usage and the arrow it sends in arrow mode. Same arrows as the factory Fn layer:
    /// / is up, right Option is left, the App key is down, right Control is right.
    public static let arrowUsages: [UInt8: UInt8] = [
        0x38: 0x52,
        0xE6: 0x50,
        0x65: 0x51,
        0xE4: 0x4F,
    ]

    /// The Fn-layer action that makes Fn+Enter send the toggle; empty if the layout has no Enter key.
    public static func fnActions(for layout: KeyLayout) -> [Int: KeyAction] {
        guard let enter = layout.keys.first(where: { $0.defaultUsage == enterUsage }) else { return [:] }
        return [enter.matrixIndex: .remap(toUsage: toggleUsage)]
    }

    private static let enterUsage: UInt8 = 0x28
}
