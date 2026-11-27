/// Arrow mode, like the RK61's Fn+Enter: the keys under the right Shift become arrow keys until toggled
/// back. The GK61 firmware has no such layer, so the app swaps the keys on the Mac (see `KeyboardToggle`).
public enum ArrowMode {
    /// Each key's HID usage and the arrow it sends in arrow mode. Same arrows as the factory Fn layer:
    /// / is up, right Option is left, the App key is down, right Control is right.
    public static let arrowUsages: [UInt8: UInt8] = [
        0x38: 0x52,
        0xE6: 0x50,
        0x65: 0x51,
        0xE4: 0x4F,
    ]

    /// The Mac-side mapping in arrow mode: each key and its arrow trade places. On a 60% board the
    /// arrows only come from Fn + those keys, so Fn + / still types / while the plain key sends ↑.
    public static let swappedUsages: [UInt8: UInt8] = arrowUsages.merging(
        arrowUsages.map { ($0.value, $0.key) }, uniquingKeysWith: { current, _ in current })
}
