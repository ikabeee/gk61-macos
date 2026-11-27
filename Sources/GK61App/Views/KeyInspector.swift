import GK61Core
import SwiftUI

/// Side panel for the selected key: its current action, held modifiers, and the key it sends.
struct KeyInspector: View {
    let key: KeyLayout.Key?
    let action: KeyAction?
    let editing: KeyEditingActions

    var body: some View {
        if let key, let action, !key.isFn {
            KeyActionEditor(key: key, action: action, editing: editing)
        } else {
            ContentUnavailableView(
                "No Key Selected", systemImage: "keyboard",
                description: Text("Click a key on the keyboard to choose what it sends."))
        }
    }
}

private struct KeyActionEditor: View {
    let key: KeyLayout.Key
    let action: KeyAction
    let editing: KeyEditingActions
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summary
            Divider()
            modifierToggles
            Divider()
            usagePicker
        }
        .padding()
    }

    private var isRemapped: Bool { action != .firmwareDefault(of: key) }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(key.label).font(.title2.bold())
            LabeledContent("Sends", value: KeyActionText.name(for: action))
            Button("Use Default") { editing.resetToDefault(key) }
                .disabled(!isRemapped)
                .help("Makes this key behave as printed again (after you apply)")
        }
    }

    private var modifierToggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hold with").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)]) {
                ForEach(ModifierChoice.all) { choice in
                    Toggle("\(choice.symbol) \(choice.name)", isOn: modifierBinding(choice.mask))
                        .toggleStyle(.checkbox)
                }
            }
        }
    }

    private var usagePicker: some View {
        let matches = KeyUsage.matching(query)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Key").font(.headline)
            TextField("Search keys", text: $query, prompt: Text("Search keys, e.g. F5 or Escape"))
                .textFieldStyle(.roundedBorder)
            List(selection: usageSelection) {
                ForEach(KeyUsage.Category.allCases, id: \.self) { category in
                    let usages = matches.filter { $0.category == category }
                    if !usages.isEmpty {
                        Section(category.rawValue) {
                            ForEach(usages) { usage in
                                Text(usage.name).tag(usage.usage)
                            }
                        }
                    }
                }
            }
            .listStyle(.bordered)
            .overlay {
                if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }

    private func modifierBinding(_ mask: ModifierMask) -> Binding<Bool> {
        Binding {
            action.modifiers.contains(mask)
        } set: { isHeld in
            var modifiers = action.modifiers
            if isHeld { modifiers.insert(mask) } else { modifiers.remove(mask) }
            editing.setModifiers(key, modifiers)
        }
    }

    private var usageSelection: Binding<UInt8?> {
        Binding {
            action.usage == 0 ? nil : action.usage
        } set: { usage in
            if let usage { editing.assignUsage(key, usage) }
        }
    }
}
