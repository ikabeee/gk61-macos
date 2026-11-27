import SwiftUI

/// The arrow-mode requests a page can make; the store performs them.
struct ArrowModeActions {
    let toggle: () -> Void
    let installToggle: () -> Void
}

/// Arrow mode on the Keys page: its switch, and the one-time Fn+Enter setup on the keyboard.
struct ArrowModeBox: View {
    let isOn: Bool
    let isToggleInstalled: Bool
    /// Why Fn+Enter can't be set up right now, or nil when it can.
    let installBlocker: String?
    let actions: ArrowModeActions

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: isOnBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arrow Mode").font(.headline)
                        Text("/ sends ↑, Right Alt ←, App ↓ and Right Ctrl →; hold Fn for the original key. Those four keys light up white while it's on.")
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                Divider()
                toggleSetup
            }
            .padding(4)
        }
        .font(.callout)
    }

    @ViewBuilder
    private var toggleSetup: some View {
        if isToggleInstalled {
            Label("Press Fn+Enter on the keyboard to switch.", systemImage: "keyboard")
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Text("Fn+Enter isn't set up on the keyboard yet.")
                Spacer()
                Button("Set Up Fn+Enter", action: actions.installToggle)
                    .disabled(installBlocker != nil)
                    .help(installBlocker ?? "Writes your applied keys to the keyboard again, with Fn+Enter as the arrow-mode switch")
            }
        }
    }

    private var isOnBinding: Binding<Bool> {
        Binding { isOn } set: { if $0 != isOn { actions.toggle() } }
    }
}
