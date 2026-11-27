import IOKit.hid

public struct DeviceInfo: Sendable, Equatable {
    public let productName: String
    public let vendorID: Int
    public let productID: Int
    public let versionNumber: Int
    public let maxOutputReportSize: Int
    public let maxInputReportSize: Int

    init(device: IOHIDDevice) {
        productName = Self.property(kIOHIDProductKey, of: device) ?? "Unknown"
        vendorID = Self.property(kIOHIDVendorIDKey, of: device) ?? 0
        productID = Self.property(kIOHIDProductIDKey, of: device) ?? 0
        versionNumber = Self.property(kIOHIDVersionNumberKey, of: device) ?? 0
        maxOutputReportSize = Self.property(kIOHIDMaxOutputReportSizeKey, of: device) ?? 0
        maxInputReportSize = Self.property(kIOHIDMaxInputReportSizeKey, of: device) ?? 0
    }

    private static func property<Value>(_ key: String, of device: IOHIDDevice) -> Value? {
        IOHIDDeviceGetProperty(device, key as CFString) as? Value
    }
}
