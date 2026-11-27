import Foundation

/// An error shown to the user with what happened and how to recover.
struct OperationFailure: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recovery: String
    let offersReconnect: Bool

    static func applyFailed(_ error: any Error) -> OperationFailure {
        OperationFailure(
            title: "Couldn't Apply to the Keyboard",
            message: DeviceErrorText.describe(error),
            recovery: "Check the cable, reconnect, and apply again. "
                + "Changes that weren't confirmed stay pending.",
            offersReconnect: true)
    }

    static func saveFailed(_ error: any Error) -> OperationFailure {
        OperationFailure(
            title: "Applied, but Not Saved on This Mac",
            message: error.localizedDescription,
            recovery: "The keyboard has the new settings, but GK61 may show older ones next launch. "
                + "Check that your Application Support folder is writable.",
            offersReconnect: false)
    }

    static func loadFailed(_ error: any Error) -> OperationFailure {
        OperationFailure(
            title: "Couldn't Read the Saved Configuration",
            message: error.localizedDescription,
            recovery: "GK61 starts from the firmware defaults. The saved file is replaced the next time you apply.",
            offersReconnect: false)
    }
}
