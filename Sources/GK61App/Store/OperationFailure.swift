import Foundation
import GK61Core

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

    static func macroTooLong(_ name: String, _ error: any Error) -> OperationFailure {
        let detail = if case let MacroError.bodyTooLong(byteCount) = error {
            "“\(name)” needs \(byteCount) bytes; the keyboard stores at most 512 per macro."
        } else {
            error.localizedDescription
        }
        return OperationFailure(
            title: "Macro Too Long for the Keyboard",
            message: detail,
            recovery: "Remove some steps on the Macros page, then assign it again.",
            offersReconnect: false)
    }

    static func toggleFailed(_ error: any Error) -> OperationFailure {
        OperationFailure(
            title: "Couldn't Switch Arrow Mode or Cmd Lock",
            message: DeviceErrorText.describe(error),
            recovery: "Reconnect the keyboard and try again. Your keys keep working as printed meanwhile.",
            offersReconnect: true)
    }

    static func toggleLightingFailed(_ error: any Error) -> OperationFailure {
        OperationFailure(
            title: "The Keys Switched, but the Lights Didn't Change",
            message: DeviceErrorText.describe(error),
            recovery: "The keys still switched. Reconnect the keyboard; GK61 updates the lights when it connects.",
            offersReconnect: true)
    }

    static func loginItemFailed(_ error: any Error) -> OperationFailure {
        OperationFailure(
            title: "Couldn't Change Open at Login",
            message: error.localizedDescription,
            recovery: "Add GK61 by hand in System Settings › General › Login Items.",
            offersReconnect: false)
    }

    static func macroLibraryLoadFailed(_ error: any Error) -> OperationFailure {
        OperationFailure(
            title: "Couldn't Read Your Macros",
            message: error.localizedDescription,
            recovery: "GK61 starts with an empty macro library. The file is replaced when you change a macro.",
            offersReconnect: false)
    }

    static func macroLibrarySaveFailed(_ error: any Error) -> OperationFailure {
        OperationFailure(
            title: "Couldn't Save Your Macros",
            message: error.localizedDescription,
            recovery: "Your latest macro edits may be missing next launch. "
                + "Check that your Application Support folder is writable.",
            offersReconnect: false)
    }
}
