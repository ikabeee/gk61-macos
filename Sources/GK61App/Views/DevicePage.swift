import Foundation
import GK61Core
import SwiftUI

struct DevicePage: View {
    let connection: ConnectionState
    let lastAppliedAt: Date?
    let savedConfigurationURL: URL
    let onReconnect: () -> Void

    var body: some View {
        content
            .navigationTitle("Device")
    }

    @ViewBuilder
    private var content: some View {
        switch connection {
        case .connecting:
            ProgressView("Connecting to the keyboard…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .connected(keyboard):
            ConnectedKeyboardForm(
                keyboard: keyboard, lastAppliedAt: lastAppliedAt,
                savedConfigurationURL: savedConfigurationURL, onReconnect: onReconnect)
        case .inputMonitoringDenied:
            InputMonitoringDeniedView(onReconnect: onReconnect)
        case .keyboardNotFound:
            unavailable(
                "No GK61 Found", systemImage: "keyboard.badge.exclamationmark",
                description: "Plug the GK61 in with its USB cable, then reconnect.")
        case let .failed(reason):
            unavailable("Couldn't Connect", systemImage: "exclamationmark.triangle", description: reason)
        }
    }

    private func unavailable(_ title: String, systemImage: String, description: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            Button("Reconnect", action: onReconnect).keyboardShortcut("r")
        }
    }
}

private struct InputMonitoringDeniedView: View {
    let onReconnect: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("Input Monitoring Needed", systemImage: "lock.shield")
        } description: {
            Text("""
                macOS only lets apps talk to a keyboard's configuration channel with Input Monitoring access. \
                Open System Settings › Privacy & Security › Input Monitoring, turn on GK61 (or the Terminal \
                you started it from), then click Reconnect. If it still fails, quit and reopen GK61.
                """)
        } actions: {
            Button("Open Privacy Settings") { openURL(Self.inputMonitoringSettings) }
                .buttonStyle(.borderedProminent)
            Button("Reconnect", action: onReconnect)
        }
    }

    private static let inputMonitoringSettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        ?? URL(fileURLWithPath: "/System/Applications/System Settings.app")
}

private struct ConnectedKeyboardForm: View {
    let keyboard: ConnectedKeyboard
    let lastAppliedAt: Date?
    let savedConfigurationURL: URL
    let onReconnect: () -> Void

    var body: some View {
        Form {
            keyboardSection
            savedConfigurationSection
            Section {
                Button("Reconnect", action: onReconnect)
            }
        }
        .formStyle(.grouped)
    }

    private var keyboardSection: some View {
        Section("Keyboard") {
            LabeledContent("Name", value: keyboard.productName)
            LabeledContent("Vendor ID", value: DeviceText.hex(keyboard.vendorID, digits: 4))
            LabeledContent("Product ID", value: DeviceText.hex(keyboard.productID, digits: 4))
            LabeledContent("Firmware", value: DeviceText.firmware(keyboard.firmwareVersion))
            LabeledContent("Signature (PSD)", value: DeviceText.psd(keyboard.psd))
            if !keyboard.isSupported {
                Label(
                    "This keyboard reports a different signature than the GK61 this app supports "
                        + "(\(DeviceText.psd(ConnectedKeyboard.supportedPSD))). Apply is disabled to protect it.",
                    systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            }
        }
    }

    private var savedConfigurationSection: some View {
        Section("Saved Configuration") {
            LabeledContent("Last applied from this Mac") {
                if let lastAppliedAt {
                    Text(lastAppliedAt, format: .dateTime)
                } else {
                    Text("Never")
                }
            }
            LabeledContent("Stored in", value: savedConfigurationURL.path(percentEncoded: false))
                .textSelection(.enabled)
            Text("""
                The keyboard can't report its settings, so GK61 shows what this Mac last applied. \
                Changes made with other software or on another computer aren't visible here.
                """)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

private enum DeviceText {
    static func hex(_ value: Int, digits: Int) -> String {
        let text = String(value, radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: max(digits - text.count, 0)) + text
    }

    /// USB `bcdDevice`: 0x0103 is version 1.03.
    static func firmware(_ bcd: Int) -> String {
        let major = String(bcd >> 8, radix: 16)
        let minor = String(bcd & 0xFF, radix: 16)
        return "\(major).\(minor.count < 2 ? "0" + minor : minor) (\(hex(bcd, digits: 4)))"
    }

    static func psd(_ psd: PSD) -> String {
        [psd.first, psd.second].map { byte in
            let text = String(byte, radix: 16, uppercase: true)
            return text.count < 2 ? "0" + text : text
        }.joined(separator: " ")
    }
}
