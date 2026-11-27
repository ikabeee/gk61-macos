import GK61Core
import GK61HID
import IOKit

enum ConnectionState: Equatable {
    case connecting
    case connected(ConnectedKeyboard)
    case inputMonitoringDenied
    case keyboardNotFound
    case failed(String)

    init(connectionError error: any Error) {
        switch error {
        case HIDTransportError.inputMonitoringDenied: self = .inputMonitoringDenied
        case HIDTransportError.deviceNotFound: self = .keyboardNotFound
        default: self = .failed(DeviceErrorText.describe(error))
        }
    }

    var connectedKeyboard: ConnectedKeyboard? {
        guard case let .connected(keyboard) = self else { return nil }
        return keyboard
    }
}

struct ConnectedKeyboard: Equatable {
    /// The signature of the `00F7-2` configuration this app's layout and modes come from.
    static let supportedPSD = PSD(0x0F, 0x0B)

    let productName: String
    let vendorID: Int
    let productID: Int
    let firmwareVersion: Int
    let psd: PSD

    init(info: DeviceInfo, psd: PSD) {
        productName = info.productName
        vendorID = info.vendorID
        productID = info.productID
        firmwareVersion = info.versionNumber
        self.psd = psd
    }

    var isSupported: Bool { psd == Self.supportedPSD }
}

/// Plain-language descriptions of transport and session errors.
enum DeviceErrorText {
    static func describe(_ error: any Error) -> String {
        switch error {
        case let KeyboardSessionError.noAcknowledgement(command):
            "The keyboard didn't answer command \(hex(command)) within 2 seconds."
        case HIDTransportError.openFailed(kIOReturnNotPermitted), HIDTransportError.sendFailed(kIOReturnNotPermitted):
            accessBlocked
        case let HIDTransportError.openFailed(code):
            "macOS couldn't open the keyboard (IOReturn \(hex(code))). Another app may be using it."
        case let HIDTransportError.sendFailed(code):
            "Sending to the keyboard failed (IOReturn \(hex(code))). It may have been unplugged."
        default:
            error.localizedDescription
        }
    }

    /// macOS refuses keyboard access while any app has secure event input on, which a focused password field turns on.
    private static let accessBlocked = """
        macOS is blocking access to the keyboard. This usually happens while a password field has focus \
        in another app, such as a browser. Click outside the password field, then reconnect. If it keeps \
        happening, check that GK61 is on in System Settings › Privacy & Security › Input Monitoring.
        """

    private static func hex(_ value: some BinaryInteger) -> String {
        "0x" + String(value, radix: 16, uppercase: true)
    }

    /// IOReturn is a signed 32-bit code; Apple documents it as unsigned hex (0xE00002E2).
    private static func hex(_ code: IOReturn) -> String {
        hex(UInt32(bitPattern: code))
    }
}
