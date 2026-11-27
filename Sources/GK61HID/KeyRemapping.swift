import Foundation

public enum KeyRemappingError: Error, Equatable {
    case hidutilFailed(status: Int32, output: String)
}

/// Swaps keys on GK61 keyboards only, through macOS's per-device key mapping (`hidutil`, Apple TN2450:
/// https://developer.apple.com/library/archive/technotes/tn2450/_index.html). The swap takes effect at
/// once and writes nothing to the keyboard; macOS drops it when the keyboard is unplugged or the Mac restarts.
public enum KeyRemapping {
    /// Replaces the GK61's mapping with `usages` (HID usage → HID usage); an empty map restores every key.
    public static func apply(_ usages: [UInt8: UInt8]) throws {
        try runHidutil(["property", "--matching", gk61Matcher, "--set", mappingProperty(usages)])
    }

    private static let gk61Matcher = #"{"VendorID":\#(HIDKeyboardTransport.vendorID)}"#

    /// TN2450 encodes a key as its HID usage page (7, keyboard) in bits 32 and up, plus its usage.
    private static func mappingProperty(_ usages: [UInt8: UInt8]) -> String {
        let pairs = usages.sorted { $0.key < $1.key }.map { source, destination in
            #"{"HIDKeyboardModifierMappingSrc":\#(keyboardUsage(source)),"HIDKeyboardModifierMappingDst":\#(keyboardUsage(destination))}"#
        }
        return #"{"UserKeyMapping":[\#(pairs.joined(separator: ","))]}"#
    }

    private static func keyboardUsage(_ usage: UInt8) -> UInt64 {
        0x7_0000_0000 | UInt64(usage)
    }

    private static func runHidutil(_ arguments: [String]) throws {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/hidutil")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw KeyRemappingError.hidutilFailed(status: process.terminationStatus, output: text)
        }
    }
}
