import Foundation
import GK61HID

// Read-only probe: finds and opens the vendor channel, then listens. It sends nothing.

let listenSeconds = 3.0

let transport = try HIDKeyboardTransport.openFirstKeyboard()
let info = transport.info
print("Opened \(info.productName) VID 0x\(hex(info.vendorID)) PID 0x\(hex(info.productID))",
      "version 0x\(hex(info.versionNumber))",
      "in/out report bytes \(info.maxInputReportSize)/\(info.maxOutputReportSize)")

let listener = Task {
    for await payload in transport.incomingReports {
        print("IN  " + payload.map { hex($0) }.joined(separator: " "))
    }
}
try await Task.sleep(for: .seconds(listenSeconds))
listener.cancel()
print("Listened \(Int(listenSeconds)) s; nothing was sent.")

func hex(_ value: some BinaryInteger) -> String {
    String(value, radix: 16, uppercase: true).leftPadded(to: 2)
}

extension String {
    func leftPadded(to width: Int) -> String {
        String(repeating: "0", count: max(0, width - count)) + self
    }
}
