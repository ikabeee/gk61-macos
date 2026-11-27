import GK61Core
import SwiftUI

/// Side panel for the selected key: what it sends, either a key with held modifiers or a library macro.
struct KeyInspector: View {
    let key: KeyLayout.Key?
    let action: KeyAction?
    let macros: [MacroDefinition]
    /// The library macro the key plays, if it plays one.
    let macroID: MacroDefinition.ID?
    let editing: KeyEditingActions

    var body: some View {
        if let key, let action, !key.isFn {
            KeyActionEditor(key: key, action: action, macros: macros, macroID: macroID, editing: editing)
                .id(key.id)
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
    let macros: [MacroDefinition]
    let macroID: MacroDefinition.ID?
    let editing: KeyEditingActions
    @State private var sendsMacro: Bool
    @State private var query = ""

    init(
        key: KeyLayout.Key, action: KeyAction, macros: [MacroDefinition], macroID: MacroDefinition.ID?,
        editing: KeyEditingActions
    ) {
        self.key = key
        self.action = action
        self.macros = macros
        self.macroID = macroID
        self.editing = editing
        _sendsMacro = State(initialValue: macroID != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summary
            Picker("Sends", selection: $sendsMacro) {
                Text("Key").tag(false)
                Text("Macro").tag(true)
            }
            .pickerStyle(.segmented)
            .help("Choose whether this key sends a key combination or plays a recorded macro")
            Divider()
            if sendsMacro {
                MacroAssignment(
                    key: key, macros: macros, macroID: macroID, playback: action.macroPlayback, editing: editing)
            } else {
                modifierToggles
                Divider()
                usagePicker
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var isRemapped: Bool { action != .firmwareDefault(of: key) }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(key.label).font(.title2.bold())
            LabeledContent("Sends", value: sendsDescription)
            Button("Use Default") {
                editing.resetToDefault(key)
                sendsMacro = false
            }
            .disabled(!isRemapped)
            .help("Makes this key behave as printed again (after you apply)")
        }
    }

    private var sendsDescription: String {
        guard let name = macros.first(where: { $0.id == macroID })?.name else { return KeyActionText.name(for: action) }
        return "Macro “\(name)”"
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

/// Picks the library macro a key plays and how a press plays it.
private struct MacroAssignment: View {
    let key: KeyLayout.Key
    let macros: [MacroDefinition]
    let macroID: MacroDefinition.ID?
    let playback: MacroPlayback?
    let editing: KeyEditingActions

    var body: some View {
        if macros.isEmpty {
            ContentUnavailableView {
                Label("No Macros", systemImage: "record.circle")
            } description: {
                Text("Record a macro on the Macros page, then come back to assign it to \(key.label).")
            } actions: {
                Button("Open Macros", action: editing.openMacros)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                macroPicker
                if let playback {
                    playbackControls(playback)
                }
                Button("Edit Macros…", action: editing.openMacros)
                    .help("Record or change macros on the Macros page")
            }
        }
    }

    private var macroPicker: some View {
        Picker("Macro", selection: macroSelection) {
            Text("Choose a Macro").tag(MacroDefinition.ID?.none).disabled(true)
            ForEach(macros) { macro in
                Text(macro.steps.isEmpty ? "\(macro.name) (empty)" : macro.name)
                    .tag(Optional(macro.id))
                    .disabled(macro.steps.isEmpty)
            }
        }
        .help("Empty macros can't be assigned until you record them")
    }

    private func playbackControls(_ playback: MacroPlayback) -> some View {
        let choice = PlaybackChoice(playback)
        return VStack(alignment: .leading, spacing: 6) {
            Picker("Plays", selection: choiceBinding(playback)) {
                ForEach(PlaybackChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.radioGroup)
            Text(choice.help)
                .font(.callout)
                .foregroundStyle(.secondary)
            if case let .repeatCount(count) = playback {
                Stepper(value: countBinding(count), in: 1...UInt16.max) {
                    Text(count == 1 ? "Once per press" : "\(count) times per press")
                }
            }
        }
    }

    private var macroSelection: Binding<MacroDefinition.ID?> {
        Binding { macroID } set: { id in
            if let id { editing.assignMacro(key, id) }
        }
    }

    private func choiceBinding(_ playback: MacroPlayback) -> Binding<PlaybackChoice> {
        Binding { PlaybackChoice(playback) } set: { choice in
            editing.setPlayback(key, choice.playback(replacing: playback))
        }
    }

    private func countBinding(_ count: UInt16) -> Binding<UInt16> {
        Binding { count } set: { editing.setPlayback(key, .repeatCount($0)) }
    }
}
