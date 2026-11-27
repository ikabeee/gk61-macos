/// Port to the keyboard's vendor HID channel. Adapters own the report ID framing;
/// the core only sees the 63-byte payload.
public protocol KeyboardTransport: Sendable {
    /// Input report payloads from the vendor channel, in arrival order.
    var incomingReports: AsyncStream<[UInt8]> { get }

    /// Sends one output report payload. Shorter payloads are zero-padded.
    func send(_ payload: [UInt8]) throws
}

public enum VendorChannel {
    public static let reportID: UInt8 = 0x04
    public static let payloadLength = 63
}
