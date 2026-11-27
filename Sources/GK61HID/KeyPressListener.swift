import Foundation
import IOKit.hid

/// Calls `onPress` on the main thread whenever a GK61 key that sends `usage` goes down, and
/// `onKeyboardConnected` whenever a GK61 appears (also once per keyboard already plugged in).
/// It listens without seizing the keyboard, so the key still reaches macOS. Needs Input Monitoring.
///
/// `@unchecked Sendable`: the manager is only touched here and its callbacks arrive on the main queue.
public final class KeyPressListener: @unchecked Sendable {
    private let manager: IOHIDManager
    private let usage: UInt8
    private let onPress: @MainActor () -> Void
    private let onKeyboardConnected: @MainActor () -> Void
    private var lastPressUptime: TimeInterval = 0

    public init(
        usage: UInt8, onPress: @escaping @MainActor () -> Void,
        onKeyboardConnected: @escaping @MainActor () -> Void
    ) throws {
        self.usage = usage
        self.onPress = onPress
        self.onKeyboardConnected = onKeyboardConnected
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, Self.keyboardCollectionMatchers() as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, Self.onValue, context)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.onDeviceMatched, context)
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
        guard listener.isPress(of: listener.usage, in: value), listener.isNewPress() else { return }
        MainActor.assumeIsolated { listener.onPress() }
    }

    private static let onDeviceMatched: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let listener = Unmanaged<KeyPressListener>.fromOpaque(context).takeUnretainedValue()
        MainActor.assumeIsolated { listener.onKeyboardConnected() }
    }

    /// The GK61 has two keyboard collections, so one key press can arrive twice within a few milliseconds.
    private func isNewPress() -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        defer { lastPressUptime = now }
        return now - lastPressUptime > Self.samePressWindow
    }

    private static let samePressWindow: TimeInterval = 0.2

    private func isPress(of usage: UInt8, in value: IOHIDValue) -> Bool {
        let element = IOHIDValueGetElement(value)
        return IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad
            && IOHIDElementGetUsage(element) == UInt32(usage)
            && IOHIDValueGetIntegerValue(value) == 1
    }
}
