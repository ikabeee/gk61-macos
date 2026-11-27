import GK61Core
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case keys = "Keys"
    case lighting = "Lighting"
    case macros = "Macros"
    case shortcuts = "Shortcuts"
    case device = "Device"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .keys: "keyboard"
        case .lighting: "lightbulb"
        case .macros: "record.circle"
        case .shortcuts: "command"
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
                macros: store.macros, macroSources: store.draftMacroSources,
                selectedKeyID: $store.selectedKeyID, editing: keyEditing, toggles: togglesBox)
        case .lighting:
            LightingPage(
                lighting: store.draftLighting, keys: store.layout.keys,
                hasEverApplied: store.applied.lighting != nil, editing: lightingEditing)
        case .macros:
            MacrosPage(macros: store.macros, keyLabels: keyLabels(playing:), editing: macroEditing)
        case .shortcuts:
            ShortcutsPage(
                keys: store.layout.keys, shortcuts: FnShortcut.factory(appToggles: Set(KeyboardToggle.allCases.filter(store.isInstalled))))
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
        ToolbarItem {
            Toggle(isOn: arrowModeBinding) {
                Label("Arrow Mode", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            }
            .toggleStyle(.button)
            .help(store.isArrowModeOn
                ? "Arrow mode is on: / ↑, Right Alt ←, App ↓, Right Ctrl →. Click or press Fn+Enter to turn it off."
                : "Turn on arrow mode: / ↑, Right Alt ←, App ↓, Right Ctrl →")
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
            resetAllToDefault: store.resetAllKeysToDefault,
            assignMacro: { store.assignMacro($1, to: $0) },
            setPlayback: { store.setPlayback($1, for: $0) },
            openMacros: { section = .macros })
    }

    private var togglesBox: KeyboardTogglesBox {
        KeyboardTogglesBox(
            activeToggles: store.activeToggles, areTogglesInstalled: store.areAllTogglesInstalled,
            installBlocker: StatusText.toggleInstallBlocker(store.applyBlocker),
            actions: KeyboardToggleActions(
                toggle: store.toggle,
                install: { Task { await store.installToggles() } }))
    }

    private var arrowModeBinding: Binding<Bool> {
        Binding { store.isArrowModeOn } set: { if $0 != store.isArrowModeOn { store.toggleArrowMode() } }
    }

    private var macroEditing: MacroEditingActions {
        MacroEditingActions(
            create: store.createMacro,
            rename: { store.renameMacro($0, to: $1) },
            setSteps: { store.setSteps($1, ofMacro: $0) },
            delete: store.deleteMacro)
    }

    private func keyLabels(playing id: MacroDefinition.ID) -> [String] {
        store.keys(playing: id).map(\.label)
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

    /// Setting up the Fn keys writes the applied keymap, so it needs everything Apply needs except pending changes.
    static func toggleInstallBlocker(_ blocker: ApplyBlocker?) -> String? {
        switch blocker {
        case nil, .nothingPending: nil
        case .applying, .disconnected, .unsupportedKeyboard: applyHelp(blocker)
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
