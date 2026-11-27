import AppKit
import GK61Core
import GK61HID
import Observation

/// Captures the keys typed in GK61's window while recording. The events are consumed, so typing
/// a shortcut records it instead of triggering it. Needs no extra permission: it only sees this app.
/// https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:)
@Observable @MainActor
final class MacroRecorder {
    private(set) var isRecording = false
    private(set) var recordedCount = 0

    @ObservationIgnored private var events: [RecordedKeyEvent] = []
    @ObservationIgnored private var heldModifiers: Set<UInt8> = []
    @ObservationIgnored private var startTime: TimeInterval = 0
    @ObservationIgnored private var monitor: Any?

    func start() {
        events = []
        heldModifiers = []
        recordedCount = 0
        startTime = ProcessInfo.processInfo.systemUptime
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            // Local monitors run on the main thread.
            MainActor.assumeIsolated { self?.record(event) }
            return nil
        }
    }

    /// Stops capturing and returns the recording as macro steps.
    func stop() -> [MacroStep] {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        return MacroRecording.steps(from: events)
    }

    private func record(_ event: NSEvent) {
        guard let usage = MacKeyCode.hidUsage(for: event.keyCode) else { return }
        events.append(RecordedKeyEvent(usage: usage, isDown: isPress(event, usage: usage), time: .seconds(event.timestamp - startTime)))
        recordedCount = events.count
    }

    /// Modifier keys only report "flags changed"; the first change of a modifier is its press, the next its release.
    private func isPress(_ event: NSEvent, usage: UInt8) -> Bool {
        switch event.type {
        case .keyDown:
            return true
        case .flagsChanged where heldModifiers.contains(usage):
            heldModifiers.remove(usage)
            return false
        case .flagsChanged:
            heldModifiers.insert(usage)
            return true
        default:
            return false
        }
    }
}
