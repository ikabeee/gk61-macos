import GK61Core
import SwiftUI

/// The key edits a page can request; the store performs them.
struct KeyEditingActions {
    let assignUsage: (KeyLayout.Key, UInt8) -> Void
    let setModifiers: (KeyLayout.Key, ModifierMask) -> Void
    let resetToDefault: (KeyLayout.Key) -> Void
    let resetAllToDefault: () -> Void
    let assignMacro: (KeyLayout.Key, MacroDefinition.ID) -> Void
    let setPlayback: (KeyLayout.Key, MacroPlayback) -> Void
    let openMacros: () -> Void
}

struct KeysPage: View {
    let keys: [KeyLayout.Key]
    let keyActions: [Int: KeyAction]
    let pendingKeyIDs: Set<KeyLayout.Key.ID>
    let macros: [MacroDefinition]
    /// The library macro each macro key plays, by key ID.
    let macroSources: [KeyLayout.Key.ID: MacroDefinition.ID]
    @Binding var selectedKeyID: KeyLayout.Key.ID?
    let editing: KeyEditingActions
    let toggles: KeyboardTogglesBox
    @State private var showsInspector = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            KeyboardView(keys: keys, selectedKeyID: selectedKeyID, appearance: appearance(of:)) { key in
                selectedKeyID = key.id
                showsInspector = true
            }
            footer
            toggles
                .frame(maxWidth: 640)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Keys")
        .inspector(isPresented: $showsInspector) {
            KeyInspector(
                key: selectedKey, action: selectedKey.map(keyActions.effectiveAction(of:)), macros: macros,
                macroID: selectedKey.flatMap { macroSources[$0.id] }, editing: editing)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
        .toolbar {
            ToolbarItem {
                Button { showsInspector.toggle() } label: {
                    Label("Key Inspector", systemImage: "sidebar.trailing")
                }
                .help("Show or hide the key inspector")
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Click a key to choose what it sends: another key, a combination or a macro. Tinted keys are remapped.")
                Text("Changes stay pending until you click Apply. Fn can't be remapped.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            Spacer()
            Button("Reset All Keys to Default", action: editing.resetAllToDefault)
                .disabled(keyActions.isEmpty)
                .help("Clears every remap in the draft; nothing is written until you apply")
        }
    }

    private var selectedKey: KeyLayout.Key? {
        keys.first { $0.id == selectedKeyID }
    }

    private func appearance(of key: KeyLayout.Key) -> KeyCapAppearance {
        guard !key.isFn else {
            return KeyCapAppearance(caption: key.label, isEnabled: false, help: "The Fn key can't be remapped")
        }
        guard let action = keyActions[key.id] else {
            return defaultAppearance(of: key)
        }
        let pendingNote = pendingKeyIDs.contains(key.id) ? " (not applied yet)" : ""
        return KeyCapAppearance(
            caption: key.label,
            detail: "→ " + KeyActionText.symbol(for: action),
            isEmphasized: true,
            help: "\(key.label) \(actionDescription(of: key, action))\(pendingNote)")
    }

    /// In arrow mode, a key left on its default shows the arrow it sends on this Mac.
    private func defaultAppearance(of key: KeyLayout.Key) -> KeyCapAppearance {
        guard toggles.activeToggles.contains(.arrowMode), let usage = key.defaultUsage, let arrow = ArrowMode.arrowUsages[usage] else {
            return KeyCapAppearance(caption: key.label, help: "\(key.label): default")
        }
        let symbol = KeyActionText.symbol(for: .remap(toUsage: arrow))
        return KeyCapAppearance(caption: key.label, detail: symbol, help: "\(key.label) sends \(symbol) in arrow mode")
    }

    private func actionDescription(of key: KeyLayout.Key, _ action: KeyAction) -> String {
        guard let name = macros.first(where: { $0.id == macroSources[key.id] })?.name else {
            return "sends \(KeyActionText.name(for: action))"
        }
        return "plays the macro “\(name)”"
    }
}
