import AppKit
import GK61Core
import GK61Storage
import SwiftUI

@main
struct GK61App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var launch = AppLaunch.start()

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
    }
}

/// The store exists only when the bundled key layout loads.
enum AppLaunch {
    case ready(ConfiguratorStore)
    case failed(String)

    @MainActor
    static func start() -> AppLaunch {
        do {
            return .ready(ConfiguratorStore(layout: try KeyLayout.gk61(), configurationFile: .standard))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

private struct KeyboardCommands: Commands {
    let launch: AppLaunch

    var body: some Commands {
        CommandGroup(after: .newItem) {
            if case let .ready(store) = launch {
                Button("Reconnect Keyboard") { Task { await store.connect() } }
                    .keyboardShortcut("r")
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
