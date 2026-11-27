import GK61Core
import SwiftUI

/// The keyboard's built-in Fn shortcuts: drawn on the keycaps, then listed by what they do.
struct ShortcutsPage: View {
    let keys: [KeyLayout.Key]
    let shortcuts: [FnShortcut]
    @State private var selectedKeyID: KeyLayout.Key.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KeyboardView(keys: keys, selectedKeyID: selectedKeyID, appearance: appearance(of:)) { key in
                    selectedKeyID = key.id
                }
                .frame(maxHeight: 300)
                selectionLine
                ShortcutGroups(shortcuts: shortcuts, keyLabels: keyLabels)
                Text("From the keyboard's factory Fn table in the Windows driver. Remapping a key on the Keys page doesn't change its Fn function.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("Shortcuts")
    }

    private var selectionLine: some View {
        Text(selectionText)
            .font(.callout)
            .foregroundStyle(selectedKeyID == nil ? .secondary : .primary)
    }

    private var selectionText: String {
        guard let key = keys.first(where: { $0.id == selectedKeyID }) else {
            return "Hold Fn and press a highlighted key. Click a key to see what it does."
        }
        guard let shortcut = shortcut(for: key) else { return "Fn + \(key.label) types \(key.label)." }
        return "Fn + \(key.label): \(shortcut.name)" + (shortcut.note.map { " (\($0))" } ?? "")
    }

    private func appearance(of key: KeyLayout.Key) -> KeyCapAppearance {
        if key.isFn {
            return KeyCapAppearance(caption: key.label, isEmphasized: true, help: "Hold Fn for the functions shown")
        }
        guard let shortcut = shortcut(for: key) else {
            return KeyCapAppearance(caption: key.label, foreground: .secondary, help: "No Fn function")
        }
        return KeyCapAppearance(
            caption: key.label, detail: shortcut.legend, isEmphasized: true,
            help: "Fn + \(key.label): \(shortcut.name)")
    }

    /// The printed label of each key, by its HID usage.
    private var keyLabels: [UInt8: String] {
        Dictionary(keys.compactMap { key in key.defaultUsage.map { ($0, key.label) } }, uniquingKeysWith: { first, _ in first })
    }

    private func shortcut(for key: KeyLayout.Key) -> FnShortcut? {
        shortcuts.first { $0.usage == key.defaultUsage }
    }
}

/// One box per group, laid out in as many columns as fit.
private struct ShortcutGroups: View {
    let shortcuts: [FnShortcut]
    let keyLabels: [UInt8: String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), alignment: .top)], alignment: .leading, spacing: 16) {
            ForEach(FnShortcut.Group.allCases) { group in
                GroupBox(group.rawValue) {
                    ShortcutRows(shortcuts: shortcuts.filter { $0.group == group }, keyLabels: keyLabels)
                }
            }
        }
    }
}

private struct ShortcutRows: View {
    let shortcuts: [FnShortcut]
    let keyLabels: [UInt8: String]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(shortcuts) { shortcut in
                GridRow {
                    Text("Fn + \(keyLabels[shortcut.usage] ?? "?")")
                        .monospaced()
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(shortcut.name)
                        if let note = shortcut.note {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
    }
}
