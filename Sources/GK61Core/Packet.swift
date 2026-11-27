/// One vendor-channel payload: always `VendorChannel.payloadLength` bytes, zero-padded.
/// Byte layouts are documented in docs/protocol.md.
public struct Packet: Equatable, Sendable {
    public let bytes: [UInt8]

    public var command: UInt8 { bytes[0] }

    init(_ leadingBytes: [UInt8]) {
        precondition(leadingBytes.count <= VendorChannel.payloadLength, "Packet longer than the vendor report")
        bytes = leadingBytes + Array(repeating: 0, count: VendorChannel.payloadLength - leadingBytes.count)
    }
}

extension Packet {
    public static let getPSD = Packet([0xA0, 0x02, 0x00, 0x01])
}
