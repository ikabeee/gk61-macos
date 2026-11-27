import Foundation
import GK61Core
import GK61HID

// Probe: opens the vendor channel and sends only GetPSD, the read-only query the
// Windows driver sends on every connect. Every packet in and out is printed.

let transport = try HIDKeyboardTransport.openFirstKeyboard()
let info = transport.info
print("Opened \(info.productName) VID 0x\(hex(info.vendorID)) PID 0x\(hex(info.productID))",
      "version 0x\(hex(info.versionNumber))",
      "in/out report bytes \(info.maxInputReportSize)/\(info.maxOutputReportSize)")

let session = KeyboardSession(transport: LoggingTransport(wrapping: transport))
let psd = try await session.readPSD()
print("PSD \(hex(psd.first)) \(hex(psd.second))")

/// Prints every payload that crosses the transport.
struct LoggingTransport: KeyboardTransport {
    let incomingReports: AsyncStream<[UInt8]>
    private let wrapped: KeyboardTransport

    init(wrapping wrapped: KeyboardTransport) {
        self.wrapped = wrapped
        let replies = wrapped.incomingReports
        incomingReports = AsyncStream { continuation in
            let forwarder = Task {
                for await payload in replies {
                    print("IN  " + hexDump(payload))
                    continuation.yield(payload)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in forwarder.cancel() }
        }
    }

    func send(_ payload: [UInt8]) throws {
        print("OUT " + hexDump(payload))
        try wrapped.send(payload)
    }
}

func hexDump(_ payload: [UInt8]) -> String {
    payload.map { hex($0) }.joined(separator: " ")
}

func hex(_ value: some BinaryInteger) -> String {
    let digits = String(value, radix: 16, uppercase: true)
    return String(repeating: "0", count: max(0, 2 - digits.count)) + digits
}
