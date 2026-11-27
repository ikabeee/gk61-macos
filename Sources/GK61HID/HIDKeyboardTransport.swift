import Foundation
import GK61Core
import IOKit.hid

public enum HIDTransportError: Error, Equatable {
    case inputMonitoringDenied
    case deviceNotFound
    case openFailed(IOReturn)
    case sendFailed(IOReturn)
    case payloadTooLong(Int)
}

/// IOKit adapter for the GK61 vendor collection (usage page 0xFF00, report ID 0x04).
///
/// `@unchecked Sendable`: the IOHIDDevice is only touched by IOKit calls that are safe
/// from any thread, and input callbacks arrive on the private serial `queue`.
public final class HIDKeyboardTransport: KeyboardTransport, @unchecked Sendable {
    public static let vendorID = 0x32E3
    public static let supportedProductIDs = [0x00F6, 0x00F7]
    static let vendorUsagePage = 0xFF00

    public let incomingReports: AsyncStream<[UInt8]>
    public let info: DeviceInfo

    private let device: IOHIDDevice
    private let continuation: AsyncStream<[UInt8]>.Continuation
    private let queue = DispatchQueue(label: "gk61.hid.input")
    private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: VendorChannel.payloadLength + 1)

    public static func openFirstKeyboard() throws -> HIDKeyboardTransport {
        try requireInputMonitoringAccess()
        guard let device = matchingDevices().first else { throw HIDTransportError.deviceNotFound }
        return try HIDKeyboardTransport(device: device)
    }

    public static func matchingDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, vendorCollectionMatchers() as CFArray)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return Array(devices)
    }

    private init(device: IOHIDDevice) throws {
        self.device = device
        self.info = DeviceInfo(device: device)
        (incomingReports, continuation) = AsyncStream.makeStream(of: [UInt8].self)
        try openAndListen()
    }

    deinit {
        IOHIDDeviceCancel(device)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        continuation.finish()
        inputBuffer.deallocate()
    }

    public func send(_ payload: [UInt8]) throws {
        guard payload.count <= VendorChannel.payloadLength else {
            throw HIDTransportError.payloadTooLong(payload.count)
        }
        let report = outputReport(for: payload)
        let result = IOHIDDeviceSetReport(
            device, kIOHIDReportTypeOutput, CFIndex(VendorChannel.reportID), report, report.count)
        guard result == kIOReturnSuccess else { throw HIDTransportError.sendFailed(result) }
    }

    private static func requireInputMonitoringAccess() throws {
        // The vendor collection shares its USB interface with the keyboard collection,
        // and macOS gates opening keyboard interfaces behind Input Monitoring.
        guard IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
            || IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        else { throw HIDTransportError.inputMonitoringDenied }
    }

    private static func vendorCollectionMatchers() -> [[String: Int]] {
        supportedProductIDs.map { productID in
            [
                kIOHIDVendorIDKey: vendorID,
                kIOHIDProductIDKey: productID,
                kIOHIDDeviceUsagePageKey: vendorUsagePage,
            ]
        }
    }

    private func openAndListen() throws {
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else { throw HIDTransportError.openFailed(result) }
        IOHIDDeviceRegisterInputReportCallback(
            device, inputBuffer, VendorChannel.payloadLength + 1,
            Self.onInputReport, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceSetDispatchQueue(device, queue)
        IOHIDDeviceActivate(device)
    }

    private func outputReport(for payload: [UInt8]) -> [UInt8] {
        let padding = [UInt8](repeating: 0, count: VendorChannel.payloadLength - payload.count)
        return [VendorChannel.reportID] + payload + padding
    }

    private static let onInputReport: IOHIDReportCallback = { context, _, _, _, reportID, report, length in
        guard let context, reportID == VendorChannel.reportID else { return }
        let transport = Unmanaged<HIDKeyboardTransport>.fromOpaque(context).takeUnretainedValue()
        transport.continuation.yield(payloadOfInputReport(report, length: length))
    }

    /// IOKit hands numbered reports with the report ID still in byte 0.
    private static func payloadOfInputReport(_ report: UnsafeMutablePointer<UInt8>, length: CFIndex) -> [UInt8] {
        Array(UnsafeBufferPointer(start: report, count: length).dropFirst())
    }
}
