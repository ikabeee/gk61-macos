import GK61Core
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case keys = "Keys"
    case lighting = "Lighting"
    case macros = "Macros"
    case device = "Device"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .keys: "keyboard"
        case .lighting: "lightbulb"
        case .macros: "record.circle"
        case .device: "info.circle"
        }
    }
}

/// Wires the store to the presentational pages, the toolbar and the error alert.
struct RootView: View {
    @Bindable var store: ConfiguratorStore
    @State private var section: SidebarSection? = .keys

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $section) { section in
                Label(section.rawValue, systemImage: section.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            detail
                .navigationSubtitle(StatusText.subtitle(pendingChanges: store.pendingChangeCount))
                .toolbar { toolbarContent }
        }
        .task { await store.connect() }
        .alert(
            store.failure?.title ?? "", isPresented: isShowingFailure, presenting: store.failure
        ) { failure in
            Button("OK", role: .cancel) {}
            if failure.offersReconnect {
                Button("Reconnect") { reconnect() }
            }
        } message: { failure in
            Text("\(failure.message)\n\n\(failure.recovery)")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section ?? .keys {
        case .keys:
            KeysPage(
                keys: store.layout.keys, keyActions: store.draftKeyActions, pendingKeyIDs: store.pendingKeyIDs,
                selectedKeyID: $store.selectedKeyID, editing: keyEditing)
        case .lighting:
            LightingPage(
                lighting: store.draftLighting, keys: store.layout.keys,
                hasEverApplied: store.applied.lighting != nil, editing: lightingEditing)
        case .macros:
            MacrosPage()
        case .device:
            DevicePage(
                connection: store.connection, lastAppliedAt: store.applied.appliedAt,
                savedConfigurationURL: store.savedConfigurationURL, onReconnect: reconnect)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ConnectionBadge(connection: store.connection) { section = .device }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let step = store.applyStep {
                ProgressView().controlSize(.small)
                Text(StatusText.progress(step)).foregroundStyle(.secondary)
            }
            Button("Revert", systemImage: "arrow.uturn.backward") { store.revert() }
                .disabled(store.pendingChangeCount == 0 || store.applyStep != nil)
                .help("Discard unapplied changes and show the last applied configuration again")
            Button("Apply", systemImage: "square.and.arrow.down") { Task { await store.apply() } }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s")
                .disabled(store.applyBlocker != nil)
                .help(StatusText.applyHelp(store.applyBlocker))
        }
    }

    private var isShowingFailure: Binding<Bool> {
        Binding { store.failure != nil } set: { isShowing in
            if !isShowing { store.failure = nil }
        }
    }

    private var keyEditing: KeyEditingActions {
        KeyEditingActions(
            assignUsage: { store.assign(usage: $1, to: $0) },
            setModifiers: { store.setModifiers($1, for: $0) },
            resetToDefault: store.resetToDefault,
            resetAllToDefault: store.resetAllKeysToDefault)
    }

    private var lightingEditing: LightingEditingActions {
        LightingEditingActions(
            selectMode: store.selectMode,
            setSpeed: store.setSpeed,
            setBrightness: store.setBrightness,
            setColor: store.setColor,
            paintKey: { store.paint($0, with: $1) },
            paintAllKeys: store.paintAllKeys)
    }

    private func reconnect() {
        Task { await store.connect() }
    }
}

/// Connection status in the toolbar; clicking it opens the Device page.
private struct ConnectionBadge: View {
    let connection: ConnectionState
    let onOpenDevice: () -> Void

    var body: some View {
        Button(action: onOpenDevice) {
            HStack(spacing: 6) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                Text(StatusText.connection(connection))
            }
        }
        .help("Show device details")
        .accessibilityLabel("Connection: \(StatusText.connection(connection))")
    }

    private var dotColor: Color {
        switch connection {
        case .connecting: .yellow
        case let .connected(keyboard): keyboard.isSupported ? .green : .orange
        case .inputMonitoringDenied, .keyboardNotFound, .failed: .red
        }
    }
}

private enum StatusText {
    static func subtitle(pendingChanges: Int) -> String {
        switch pendingChanges {
        case 0: "No unapplied changes"
        case 1: "1 unapplied change"
        default: "\(pendingChanges) unapplied changes"
        }
    }

    static func connection(_ connection: ConnectionState) -> String {
        switch connection {
        case .connecting: "Connecting…"
        case let .connected(keyboard): keyboard.isSupported ? "\(keyboard.productName) connected" : "Unsupported keyboard"
        case .inputMonitoringDenied: "Needs Input Monitoring"
        case .keyboardNotFound: "No keyboard"
        case .failed: "Connection failed"
        }
    }

    static func progress(_ step: ApplyStep) -> String {
        switch step {
        case .lighting: "Applying lighting…"
        case .keymap: "Applying keys…"
        }
    }

    static func applyHelp(_ blocker: ApplyBlocker?) -> String {
        switch blocker {
        case nil: "Write the unapplied changes to the keyboard. They stay on the keyboard after you unplug it."
        case .applying: "Applying…"
        case .disconnected: "Connect the keyboard to apply (see the Device page)"
        case .unsupportedKeyboard: "This keyboard's signature isn't supported, so GK61 won't write to it"
        case .nothingPending: "Nothing to apply"
        }
    }
}
