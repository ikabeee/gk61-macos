import GK61Core
import SwiftUI

/// The key edits a page can request; the store performs them.
struct KeyEditingActions {
    let assignUsage: (KeyLayout.Key, UInt8) -> Void
    let setModifiers: (KeyLayout.Key, ModifierMask) -> Void
    let resetToDefault: (KeyLayout.Key) -> Void
    let resetAllToDefault: () -> Void
}

struct KeysPage: View {
    let keys: [KeyLayout.Key]
    let keyActions: [Int: KeyAction]
    let pendingKeyIDs: Set<KeyLayout.Key.ID>
    @Binding var selectedKeyID: KeyLayout.Key.ID?
    let editing: KeyEditingActions
    @State private var showsInspector = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            KeyboardView(keys: keys, selectedKeyID: selectedKeyID, appearance: appearance(of:)) { key in
                selectedKeyID = key.id
                showsInspector = true
            }
            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Keys")
        .inspector(isPresented: $showsInspector) {
            KeyInspector(key: selectedKey, action: selectedKey.map(keyActions.effectiveAction(of:)), editing: editing)
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
                Text("Click a key to choose what it sends. Tinted keys are remapped; an arrow shows their new action.")
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
            return KeyCapAppearance(caption: key.label, help: "\(key.label): default")
        }
        let pendingNote = pendingKeyIDs.contains(key.id) ? " (not applied yet)" : ""
        return KeyCapAppearance(
            caption: key.label,
            detail: "→ " + KeyActionText.symbol(for: action),
            isEmphasized: true,
            help: "\(key.label) sends \(KeyActionText.name(for: action))\(pendingNote)")
    }
}
