import GK61Core
import SwiftUI

/// The toggle requests a page can make; the store performs them.
struct KeyboardToggleActions {
    let toggle: (KeyboardToggle) -> Void
    let install: () -> Void
}

/// Arrow mode and Cmd lock on the Keys page: their switches, and the one-time Fn-key setup on the keyboard.
struct KeyboardTogglesBox: View {
    let activeToggles: Set<KeyboardToggle>
    let areTogglesInstalled: Bool
    /// Why the Fn keys can't be set up right now, or nil when they can.
    let installBlocker: String?
    let actions: KeyboardToggleActions

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                switchRow(
                    .arrowMode, title: "Arrow Mode", fnKey: "Fn+Enter",
                    detail: "/ sends ↑, Right Alt ←, App ↓ and Right Ctrl →; hold Fn for the original key. Those four keys light up white.")
                Divider()
                switchRow(
                    .commandLock, title: "Cmd Lock", fnKey: "Fn+Win",
                    detail: "Left Win (Command) does nothing, so you can't hit it by accident. The key lights up red.")
                Divider()
                setupRow
            }
            .padding(4)
        }
        .font(.callout)
    }

    private func switchRow(_ toggle: KeyboardToggle, title: String, fnKey: String, detail: String) -> some View {
        Toggle(isOn: binding(for: toggle)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline) + Text("  \(fnKey)").foregroundStyle(.secondary)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }

    private var setupRow: some View {
        HStack {
            setupStatus
            Spacer()
            Button(areTogglesInstalled ? "Write Fn Keys Again" : "Set Up Fn Keys", action: actions.install)
                .disabled(installBlocker != nil)
                .help(installBlocker ?? setupHelp)
        }
    }

    @ViewBuilder
    private var setupStatus: some View {
        if areTogglesInstalled {
            Label("Press Fn+Enter or Fn+Win on the keyboard to switch. Works while GK61 is running.", systemImage: "keyboard")
                .foregroundStyle(.secondary)
        } else {
            Text("Fn+Enter and Fn+Win aren't set up on the keyboard yet.")
        }
    }

    private var setupHelp: String {
        areTogglesInstalled
            ? "If Fn+Enter or Fn+Win stopped switching (for example, another app rewrote the keyboard), this writes them again"
            : "Writes your applied keys to the keyboard again, with Fn+Enter and Fn+Win as switches"
    }

    private func binding(for toggle: KeyboardToggle) -> Binding<Bool> {
        Binding { activeToggles.contains(toggle) } set: { isOn in
            if isOn != activeToggles.contains(toggle) { actions.toggle(toggle) }
        }
    }
}
