import GK61Core
import SwiftUI

/// The macro edits a page can request; the store performs them.
struct MacroEditingActions {
    let create: () -> MacroDefinition.ID
    let rename: (MacroDefinition.ID, String) -> Void
    let setSteps: (MacroDefinition.ID, [MacroStep]) -> Void
    let delete: (MacroDefinition.ID) -> Void
}

/// The macro library: pick a macro on the left, record and edit it on the right.
struct MacrosPage: View {
    let macros: [MacroDefinition]
    /// Labels of the keys that play a macro, for "Used by".
    let keyLabels: (MacroDefinition.ID) -> [String]
    let editing: MacroEditingActions
    @State private var selectedID: MacroDefinition.ID?
    @State private var pendingDeletion: MacroDefinition?

    var body: some View {
        HStack(spacing: 0) {
            library
                .frame(width: 220)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Macros")
        .onAppear { selectedID = selectedID ?? macros.first?.id }
        .confirmationDialog(
            "Delete “\(pendingDeletion?.name ?? "")”?", isPresented: isConfirmingDeletion, presenting: pendingDeletion
        ) { macro in
            Button("Delete Macro", role: .destructive) { delete(macro) }
        } message: { macro in
            Text("\(keyLabels(macro.id).formatted(.list(type: .and))) will go back to their default action. "
                + "Nothing changes on the keyboard until you apply.")
        }
    }

    private var library: some View {
        VStack(spacing: 0) {
            List(macros, selection: $selectedID) { macro in
                Label(macro.name, systemImage: "record.circle")
            }
            .overlay {
                if macros.isEmpty {
                    ContentUnavailableView(
                        "No Macros", systemImage: "record.circle",
                        description: Text("Click + to record your first macro."))
                }
            }
            Divider()
            HStack(spacing: 0) {
                Button("New Macro", systemImage: "plus") { selectedID = editing.create() }
                    .help("Create an empty macro to record into")
                Button("Delete Macro", systemImage: "minus") { requestDeletion() }
                    .disabled(selectedMacro == nil)
                    .help("Delete the selected macro")
                Spacer()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(6)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let macro = selectedMacro {
            MacroEditor(macro: macro, keyLabels: keyLabels(macro.id), editing: editing)
                .id(macro.id)
        } else {
            ContentUnavailableView(
                "No Macro Selected", systemImage: "record.circle",
                description: Text("Select a macro, or create one with +. Then assign it to a key on the Keys page."))
        }
    }

    private var selectedMacro: MacroDefinition? {
        macros.first { $0.id == selectedID }
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding { pendingDeletion != nil } set: { if !$0 { pendingDeletion = nil } }
    }

    /// Deleting a macro that no key plays needs no confirmation.
    private func requestDeletion() {
        guard let macro = selectedMacro else { return }
        if keyLabels(macro.id).isEmpty {
            delete(macro)
        } else {
            pendingDeletion = macro
        }
    }

    private func delete(_ macro: MacroDefinition) {
        let index = macros.firstIndex(of: macro) ?? 0
        editing.delete(macro.id)
        let remaining = macros.filter { $0.id != macro.id }
        selectedID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
    }
}

private struct MacroEditor: View {
    let macro: MacroDefinition
    let keyLabels: [String]
    let editing: MacroEditingActions
    @State private var recorder = MacroRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            recordingControls
            stepList
            footer
        }
        .padding(20)
        .onDisappear { if recorder.isRecording { finishRecording() } }
    }

    private var header: some View {
        TextField("Name", text: nameBinding, prompt: Text("Macro name"))
            .textFieldStyle(.roundedBorder)
            .font(.title3)
            .disabled(recorder.isRecording)
    }

    private var recordingControls: some View {
        HStack(spacing: 12) {
            if recorder.isRecording {
                Button("Stop Recording", systemImage: "stop.circle.fill", action: finishRecording)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                Text("Recording… type the keys in this window (\(recorder.recordedCount) events). Click Stop when done.")
                    .foregroundStyle(.secondary)
            } else {
                Button(macro.steps.isEmpty ? "Record" : "Record Again", systemImage: "record.circle") { recorder.start() }
                    .help(macro.steps.isEmpty
                        ? "Capture the keys you type, with the pauses between them"
                        : "Replace these steps with a new recording")
                Text("Delays are the pauses between steps, in milliseconds.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private var stepList: some View {
        List {
            ForEach(Array(macro.steps.enumerated()), id: \.offset) { index, step in
                MacroStepRow(step: step) { delay in
                    replaceStep(at: index, with: MacroStep(step.event, delayMilliseconds: delay))
                } onDelete: {
                    removeStep(at: index)
                }
            }
        }
        .listStyle(.bordered)
        .disabled(recorder.isRecording)
        .overlay {
            if macro.steps.isEmpty && !recorder.isRecording {
                ContentUnavailableView(
                    "No Steps Yet", systemImage: "keyboard",
                    description: Text("Click Record and type the keys this macro should press."))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !fitsOnKeyboard {
                Label("Too long for the keyboard. Remove some steps or delays.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            Text(keyLabels.isEmpty
                ? "Not assigned to any key. Assign it in the Keys page inspector."
                : "Used by \(keyLabels.formatted(.list(type: .and))). Edits show there as unapplied changes.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private var fitsOnKeyboard: Bool {
        (try? Macro(playback: .repeatCount(1), steps: macro.steps)) != nil
    }

    private var nameBinding: Binding<String> {
        Binding { macro.name } set: { editing.rename(macro.id, $0) }
    }

    private func finishRecording() {
        editing.setSteps(macro.id, recorder.stop())
    }

    private func replaceStep(at index: Int, with step: MacroStep) {
        var steps = macro.steps
        steps[index] = step
        editing.setSteps(macro.id, steps)
    }

    private func removeStep(at index: Int) {
        var steps = macro.steps
        steps.remove(at: index)
        editing.setSteps(macro.id, steps)
    }
}

private struct MacroStepRow: View {
    let step: MacroStep
    let onDelayChange: (UInt16) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: MacroStepText.systemImage(for: step.event))
                .foregroundStyle(.secondary)
            Text(MacroStepText.describe(step.event))
            Spacer()
            TextField("Delay", value: delayBinding, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .help("Pause after this step, 0–65535 ms")
            Text("ms").foregroundStyle(.secondary)
            Button("Remove Step", systemImage: "minus.circle", action: onDelete)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Remove this step")
        }
    }

    private var delayBinding: Binding<Int> {
        Binding { Int(step.delayMilliseconds) } set: { onDelayChange(UInt16(clamping: $0)) }
    }
}
