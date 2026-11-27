import Foundation
import IOKit.hid

/// Calls `onPress` on the main thread whenever a GK61 key that sends `usage` goes down.
/// It listens without seizing the keyboard, so the key still reaches macOS. Needs Input Monitoring.
/// Re-plugging the keyboard is handled by the IOHIDManager, which keeps matching new devices.
///
/// `@unchecked Sendable`: the manager is only touched here and its callbacks arrive on the main queue.
public final class KeyPressListener: @unchecked Sendable {
    private let manager: IOHIDManager
    private let usage: UInt8
    private let onPress: @MainActor () -> Void

    public init(usage: UInt8, onPress: @escaping @MainActor () -> Void) throws {
        self.usage = usage
        self.onPress = onPress
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, Self.keyboardCollectionMatchers() as CFArray)
        IOHIDManagerRegisterInputValueCallback(manager, Self.onValue, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerSetDispatchQueue(manager, .main)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else { throw HIDTransportError.openFailed(result) }
        IOHIDManagerActivate(manager)
    }

    deinit {
        IOHIDManagerCancel(manager)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private static func keyboardCollectionMatchers() -> [[String: Int]] {
        HIDKeyboardTransport.supportedProductIDs.map { productID in
            [
                kIOHIDVendorIDKey: HIDKeyboardTransport.vendorID,
                kIOHIDProductIDKey: productID,
                kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
            ]
        }
    }

    private static let onValue: IOHIDValueCallback = { context, _, _, value in
        guard let context else { return }
        let listener = Unmanaged<KeyPressListener>.fromOpaque(context).takeUnretainedValue()
        guard listener.isPress(of: listener.usage, in: value) else { return }
        MainActor.assumeIsolated { listener.onPress() }
    }

    private func isPress(of usage: UInt8, in value: IOHIDValue) -> Bool {
        let element = IOHIDValueGetElement(value)
        return IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad
            && IOHIDElementGetUsage(element) == UInt32(usage)
            && IOHIDValueGetIntegerValue(value) == 1
    }
}
