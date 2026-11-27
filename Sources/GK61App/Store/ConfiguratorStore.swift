import Foundation
import GK61Core
import GK61Storage
import GK61HID
import Observation

/// Container for the whole app: owns the device session, the applied configuration and the pending drafts.
/// Views read its state and call its intents; only this type does IO.
@Observable @MainActor
final class ConfiguratorStore {
    let layout: KeyLayout
    private(set) var connection: ConnectionState = .connecting
    private(set) var applyStep: ApplyStep?
    private(set) var applied: AppliedConfiguration
    private(set) var draftKeyActions: [Int: KeyAction]
    private(set) var draftLighting: Lighting
    /// The library macro each macro key in the draft plays, by matrix index.
    private(set) var draftMacroSources: [Int: UUID]
    private(set) var macros: [MacroDefinition]
    /// The keyboard toggles (arrow mode, Cmd lock) that are on on this Mac right now.
    private(set) var activeToggles: Set<KeyboardToggle> = []
    var selectedKeyID: KeyLayout.Key.ID?
    var failure: OperationFailure?

    @ObservationIgnored private var session: KeyboardSession?
    @ObservationIgnored fileprivate var toggleListener: KeyPressListener?
    @ObservationIgnored fileprivate var toggleLightingWrite: Task<Void, Never>?
    @ObservationIgnored private let configurationFile: ConfigurationFile
    @ObservationIgnored let macroLibraryFile: MacroLibraryFile

    init(layout: KeyLayout, configurationFile: ConfigurationFile, macroLibraryFile: MacroLibraryFile) {
        self.layout = layout
        self.configurationFile = configurationFile
        self.macroLibraryFile = macroLibraryFile
        applied = .nothingApplied
        draftKeyActions = [:]
        draftMacroSources = [:]
        draftLighting = Self.initialLighting
        macros = []
        restoreAppliedConfiguration()
        restoreMacroLibrary()
        applyMacMapping(for: [])
    }

    // MARK: Status

    var pendingKeyIDs: Set<KeyLayout.Key.ID> {
        Set(layout.keys.map(\.id).filter { draftKeyActions[$0] != applied.keyActions[$0] })
    }

    var hasPendingLighting: Bool { draftLighting != lightingBaseline }

    var pendingChangeCount: Int { pendingKeyIDs.count + (hasPendingLighting ? 1 : 0) }

    var savedConfigurationURL: URL { configurationFile.url }

    var applyBlocker: ApplyBlocker? {
        guard applyStep == nil else { return .applying }
        guard let keyboard = connection.connectedKeyboard else { return .disconnected }
        guard keyboard.isSupported else { return .unsupportedKeyboard }
        guard pendingChangeCount > 0 else { return .nothingPending }
        return nil
    }

    // MARK: Connection

    func connect() async {
        session = nil
        connection = .connecting
        do {
            connection = .connected(try await openSession())
            listenForToggles()
            showTogglesOnKeyboard()
        } catch {
            connection = ConnectionState(connectionError: error)
        }
    }

    private func openSession() async throws -> ConnectedKeyboard {
        let transport = try HIDKeyboardTransport.openFirstKeyboard()
        let newSession = KeyboardSession(transport: transport)
        let psd = try await newSession.readPSD()
        session = newSession
        return ConnectedKeyboard(info: transport.info, psd: psd)
    }

    // MARK: Apply and revert

    /// Writes pending lighting, then the pending keymap, in the Windows driver's Apply order.
    func apply() async {
        guard applyBlocker == nil, let session else { return }
        do {
            try await applyPendingLighting(through: session)
            try await applyPendingKeymap(through: session)
        } catch {
            failure = .applyFailed(error)
        }
        applyStep = nil
    }

    func revert() {
        draftKeyActions = applied.keyActions
        draftMacroSources = applied.macroSources
        draftLighting = lightingBaseline
    }

    private func applyPendingLighting(through session: KeyboardSession) async throws {
        guard hasPendingLighting else { return }
        applyStep = .lighting
        let lighting = draftLighting
        try await session.applyLighting(lighting)
        keyboardShownToggles = []
        recordApplied { $0.lighting = lighting }
        try await Task.sleep(for: Self.pauseBetweenOperations)
    }

    private func applyPendingKeymap(through session: KeyboardSession) async throws {
        guard !pendingKeyIDs.isEmpty else { return }
        applyStep = .keymap
        let actions = draftKeyActions
        let sources = draftMacroSources
        let fnActions = KeyboardToggle.fnActions(for: layout)
        try await session.applyKeymap(layout, actions: actions, fnActions: fnActions)
        recordApplied {
            $0.keyActions = actions
            $0.macroSources = sources
            $0.fnKeyActions = fnActions
        }
    }

    private func recordApplied(_ change: (inout AppliedConfiguration) -> Void) {
        change(&applied)
        applied.appliedAt = .now
        do {
            try configurationFile.save(applied)
        } catch {
            failure = .saveFailed(error)
        }
    }

    private func restoreAppliedConfiguration() {
        do {
            applied = try configurationFile.load()
            revert()
        } catch {
            failure = .loadFailed(error)
        }
    }

    // MARK: Key editing

    /// Picking a modifier from the list makes the key that modifier; any other key keeps the held modifiers.
    func assign(usage: UInt8, to key: KeyLayout.Key) {
        guard !KeyAction.isModifierUsage(usage) else {
            return setDraft(.remap(toUsage: usage), for: key)
        }
        let modifiers = draftKeyActions.effectiveAction(of: key).modifiers
        setDraft(.keys(modifiers: modifiers, usage: usage, secondUsage: 0), for: key)
    }

    func setModifiers(_ modifiers: ModifierMask, for key: KeyLayout.Key) {
        let current = draftKeyActions.effectiveAction(of: key)
        setDraft(.keys(modifiers: modifiers, usage: current.usage, secondUsage: current.secondUsage), for: key)
    }

    func resetToDefault(_ key: KeyLayout.Key) {
        draftKeyActions[key.id] = nil
        draftMacroSources[key.id] = nil
    }

    func resetAllKeysToDefault() {
        draftKeyActions = [:]
        draftMacroSources = [:]
    }

    /// Stores only real changes: the firmware default and an empty action both mean "no entry".
    private func setDraft(_ action: KeyAction, for key: KeyLayout.Key) {
        let isEmpty = action.modifiers.isEmpty && action.usage == 0
        let isDefault = action == .firmwareDefault(of: key)
        draftKeyActions[key.id] = isEmpty || isDefault || key.isFn ? nil : action
        draftMacroSources[key.id] = nil
    }

    // MARK: Lighting editing

    func selectMode(_ mode: LightingMode) {
        draftLighting.color = Self.color(for: mode.colorStyle, keeping: draftLighting.color)
        draftLighting.mode = mode
    }

    func setSpeed(_ level: UInt8) {
        draftLighting.speed = min(level, Self.maximumLevel)
    }

    func setBrightness(_ level: UInt8) {
        draftLighting.brightness = min(level, Self.maximumLevel)
    }

    func setColor(_ color: LightingColor) {
        draftLighting.color = color
    }

    func paint(_ key: KeyLayout.Key, with color: RGBColor) {
        var colors = perKeyColors
        colors[key.id] = color
        draftLighting.color = .perKey(colors)
    }

    func paintAllKeys(with color: RGBColor) {
        draftLighting.color = .perKey(Dictionary(uniqueKeysWithValues: layout.keys.map { ($0.id, color) }))
    }

    var perKeyColors: [Int: RGBColor] {
        guard case let .perKey(colors) = draftLighting.color else { return [:] }
        return colors
    }

    /// Lighting this Mac never applied is unknown; the initial draft stands in for it so a fresh launch shows no pending change.
    private var lightingBaseline: Lighting { applied.lighting ?? Self.initialLighting }

    private static func color(for style: LightingMode.ColorStyle, keeping current: LightingColor) -> LightingColor {
        switch (style, current) {
        case (.none, _), (.palette, .palette), (.paletteOrRainbow, .palette), (.paletteOrRainbow, .rainbow),
            (.perKey, .perKey):
            current
        case (.palette, _): .palette(.red)
        case (.paletteOrRainbow, _): .rainbow
        case (.perKey, _): .perKey([:])
        }
    }

    static let maximumLevel: UInt8 = 4
    private static let pauseBetweenOperations = Duration.milliseconds(100)
    private static let initialLighting = Lighting(
        mode: LightingMode.named("Wave spectrum") ?? LightingMode.all[0], speed: 2, brightness: 4, color: .rainbow)
}

/// The macro library and the keys that play its macros. A key holds a copy of its macro's steps;
/// editing a library macro updates every draft key that plays it, so the change shows up as pending.
extension ConfiguratorStore {
    // MARK: Library

    func createMacro() -> MacroDefinition.ID {
        let macro = MacroDefinition(name: nextMacroName(), steps: [])
        macros.append(macro)
        saveMacroLibrary()
        return macro.id
    }

    func renameMacro(_ id: MacroDefinition.ID, to name: String) {
        updateMacro(id) { $0.name = name }
    }

    func setSteps(_ steps: [MacroStep], ofMacro id: MacroDefinition.ID) {
        updateMacro(id) { $0.steps = steps }
        for key in keys(playing: id) {
            guard let playback = draftKeyActions[key.id]?.macroPlayback else { continue }
            setMacroDraft(id, playback: playback, for: key)
        }
    }

    /// Keys that played the deleted macro go back to their default action in the draft.
    func deleteMacro(_ id: MacroDefinition.ID) {
        for key in keys(playing: id) {
            resetToDefault(key)
        }
        macros.removeAll { $0.id == id }
        saveMacroLibrary()
    }

    func keys(playing id: MacroDefinition.ID) -> [KeyLayout.Key] {
        layout.keys.filter { draftMacroSources[$0.id] == id }
    }

    // MARK: Key assignment

    /// A key that already plays a macro keeps its playback mode; otherwise it plays the macro once.
    func assignMacro(_ id: MacroDefinition.ID, to key: KeyLayout.Key) {
        setMacroDraft(id, playback: draftKeyActions[key.id]?.macroPlayback ?? .repeatCount(1), for: key)
    }

    func setPlayback(_ playback: MacroPlayback, for key: KeyLayout.Key) {
        guard let id = draftMacroSources[key.id] else { return }
        setMacroDraft(id, playback: playback, for: key)
    }

    private func setMacroDraft(_ id: MacroDefinition.ID, playback: MacroPlayback, for key: KeyLayout.Key) {
        guard !key.isFn, let definition = macros.first(where: { $0.id == id }) else { return }
        do {
            draftKeyActions[key.id] = .macro(try Macro(playback: playback, steps: definition.steps))
            draftMacroSources[key.id] = id
        } catch {
            failure = .macroTooLong(definition.name, error)
        }
    }

    // MARK: Persistence

    private func restoreMacroLibrary() {
        do {
            macros = try macroLibraryFile.load()
        } catch {
            failure = .macroLibraryLoadFailed(error)
        }
    }

    private func updateMacro(_ id: MacroDefinition.ID, _ change: (inout MacroDefinition) -> Void) {
        guard let index = macros.firstIndex(where: { $0.id == id }) else { return }
        change(&macros[index])
        saveMacroLibrary()
    }

    private func saveMacroLibrary() {
        do {
            try macroLibraryFile.save(macros)
        } catch {
            failure = .macroLibrarySaveFailed(error)
        }
    }

    private func nextMacroName() -> String {
        let names = Set(macros.map(\.name))
        let number = (1...).first { !names.contains("Macro \($0)") } ?? macros.count + 1
        return "Macro \(number)"
    }
}

/// Keyboard toggles: Fn+Enter (arrow mode) and Fn+Left Win (Cmd lock) send F24 and F23; the store changes
/// the keys on this Mac and lights them on the keyboard. The Mac mapping is undone when the app starts or
/// quits, so it never outlives the app.
extension ConfiguratorStore {
    var isArrowModeOn: Bool { activeToggles.contains(.arrowMode) }
    var isCommandLockOn: Bool { activeToggles.contains(.commandLock) }

    /// True once the keyboard's Fn layer sends this toggle's signal.
    func isInstalled(_ toggle: KeyboardToggle) -> Bool {
        guard let fnKey = layout.key(withUsage: toggle.fnKeyUsage) else { return false }
        return applied.fnKeyActions[fnKey.matrixIndex] == .remap(toUsage: toggle.signalUsage)
    }

    var areAllTogglesInstalled: Bool { KeyboardToggle.allCases.allSatisfy(isInstalled) }

    func toggleArrowMode() { toggle(.arrowMode) }
    func toggleCommandLock() { toggle(.commandLock) }

    func toggle(_ toggle: KeyboardToggle) {
        applyMacMapping(for: activeToggles.symmetricDifference([toggle]))
        showTogglesOnKeyboard()
    }

    /// Writes the applied keymap again with every toggle's Fn key; unapplied key changes stay pending.
    func installToggles() async {
        guard applyStep == nil, connection.connectedKeyboard?.isSupported == true, let session else { return }
        applyStep = .keymap
        let actions = applied.keyActions
        let fnActions = KeyboardToggle.fnActions(for: layout)
        do {
            try await session.applyKeymap(layout, actions: actions, fnActions: fnActions)
            recordApplied { $0.fnKeyActions = fnActions }
        } catch {
            failure = .applyFailed(error)
        }
        applyStep = nil
    }

    fileprivate func applyMacMapping(for toggles: Set<KeyboardToggle>) {
        do {
            try KeyRemapping.apply(KeyboardToggle.macMapping(for: toggles))
            activeToggles = toggles
        } catch {
            failure = .toggleFailed(error)
        }
    }

    /// Lights the keys of the toggles that are on, and puts the applied effect back when none is.
    /// Writes queue up, so quick toggles end on the latest state.
    fileprivate func showTogglesOnKeyboard() {
        let previousWrite = toggleLightingWrite
        toggleLightingWrite = Task {
            await previousWrite?.value
            await writeToggleLighting()
        }
    }

    private func writeToggleLighting() async {
        let shown = activeToggles
        guard keyboardShownToggles != shown, applyStep == nil,
              connection.connectedKeyboard?.isSupported == true, let session else { return }
        applyStep = .lighting
        do {
            try await session.applyLighting(shown.isEmpty ? lightingBaseline : KeyboardToggle.lighting(for: layout, showing: shown))
            keyboardShownToggles = shown
        } catch {
            failure = .toggleLightingFailed(error)
        }
        applyStep = nil
    }

    /// The keyboard saves its lighting, so this outlives the app: a later connect puts the applied effect back.
    fileprivate var keyboardShownToggles: Set<KeyboardToggle> {
        get { Set((UserDefaults.standard.stringArray(forKey: Self.shownTogglesKey) ?? []).compactMap(KeyboardToggle.init(rawValue:))) }
        set { UserDefaults.standard.set(newValue.map(\.rawValue).sorted(), forKey: Self.shownTogglesKey) }
    }

    private static let shownTogglesKey = "keyboardShownToggles"

    /// macOS forgets the mapping when the keyboard is unplugged, so a reconnected keyboard gets it again.
    fileprivate func listenForToggles() {
        guard toggleListener == nil else { return }
        do {
            toggleListener = try KeyPressListener(usages: Set(KeyboardToggle.allCases.map(\.signalUsage))) { [weak self] usage in
                guard let toggle = KeyboardToggle(signalUsage: usage) else { return }
                self?.toggle(toggle)
            } onKeyboardConnected: { [weak self] in
                guard let self, !activeToggles.isEmpty else { return }
                applyMacMapping(for: activeToggles)
            }
        } catch {
            failure = .toggleFailed(error)
        }
    }
}

enum ApplyStep {
    case lighting
    case keymap
}

enum ApplyBlocker {
    case applying
    case disconnected
    case unsupportedKeyboard
    case nothingPending
}
