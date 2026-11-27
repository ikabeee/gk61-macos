import AppKit
import GK61Core
import GK61HID
import GK61Storage
import SwiftUI

@main
struct GK61App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var launch = AppLaunch.start()
    @State private var loginItem = LoginItem()

    var body: some Scene {
        Window("GK61", id: "main") {
            switch launch {
            case let .ready(store):
                RootView(store: store)
            case let .failed(reason):
                ContentUnavailableView(
                    "Keyboard Layout Missing", systemImage: "exclamationmark.triangle",
                    description: Text("GK61 couldn't load its built-in key layout (\(reason)). Reinstall the app."))
            }
        }
        .defaultSize(width: 1100, height: 640)
        .commands { KeyboardCommands(launch: launch) }

        MenuBarExtra(isInserted: .constant(launch.store != nil)) {
            if let store = launch.store {
                MenuBarMenu(store: store, loginItem: loginItem)
            }
        } label: {
            Image(systemName: launch.store?.isArrowModeOn == true ? arrowModeSymbol : "keyboard")
                .accessibilityLabel(launch.store?.isArrowModeOn == true ? "GK61, arrow mode on" : "GK61")
        }
    }

    private let arrowModeSymbol = "arrow.up.and.down.and.arrow.left.and.right"
}

/// Keeps arrow mode reachable after the window closes; the app keeps running until you quit it here.
private struct MenuBarMenu: View {
    let store: ConfiguratorStore
    let loginItem: LoginItem
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Arrow Mode", isOn: binding(for: .arrowMode))
        Toggle("Cmd Lock", isOn: binding(for: .commandLock))
        Text("Fn+Enter and Fn+Win on the keyboard also switch them")
        Divider()
        Toggle("Open at Login", isOn: opensAtLoginBinding)
        if loginItem.needsApproval {
            Button("Allow in Login Items Settings…", action: loginItem.openLoginItemsSettings)
        }
        if let failure = loginItem.failure {
            Text("\(failure.title): \(failure.message)")
        }
        Divider()
        Button("Open GK61") {
            openWindow(id: "main")
            NSApplication.shared.activate()
        }
        Divider()
        Button("Quit GK61") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func binding(for toggle: KeyboardToggle) -> Binding<Bool> {
        Binding { store.activeToggles.contains(toggle) } set: { isOn in
            if isOn != store.activeToggles.contains(toggle) { store.toggle(toggle) }
        }
    }

    private var opensAtLoginBinding: Binding<Bool> {
        Binding { loginItem.opensAtLogin } set: { loginItem.setOpensAtLogin($0) }
    }
}

/// The store exists only when the bundled key layout loads.
enum AppLaunch {
    case ready(ConfiguratorStore)
    case failed(String)

    @MainActor
    static func start() -> AppLaunch {
        do {
            return .ready(ConfiguratorStore(layout: try KeyLayout.gk61(), configurationFile: .standard, macroLibraryFile: .standard))
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    var store: ConfiguratorStore? {
        guard case let .ready(store) = self else { return nil }
        return store
    }
}

private struct KeyboardCommands: Commands {
    let launch: AppLaunch

    var body: some Commands {
        CommandGroup(after: .newItem) {
            if case let .ready(store) = launch {
                Button("Reconnect Keyboard") { Task { await store.connect() } }
                    .keyboardShortcut("r")
                Button("Toggle Arrow Mode", action: store.toggleArrowMode)
                    .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }
    }
}

/// A SwiftPM executable starts as a background process; this makes it a regular, frontmost app.
/// https://developer.apple.com/documentation/appkit/nsapplication/activate()
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    /// The menu bar item keeps arrow mode working with the window closed; quit from that menu.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Arrow mode only lives while the app runs. There is no window left to report a failure to.
    func applicationWillTerminate(_ notification: Notification) {
        try? KeyRemapping.apply([:])
    }
}
