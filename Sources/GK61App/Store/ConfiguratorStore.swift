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
    var selectedKeyID: KeyLayout.Key.ID?
    var failure: OperationFailure?

    @ObservationIgnored private var session: KeyboardSession?
    @ObservationIgnored private let configurationFile: ConfigurationFile

    init(layout: KeyLayout, configurationFile: ConfigurationFile) {
        self.layout = layout
        self.configurationFile = configurationFile
        applied = .nothingApplied
        draftKeyActions = [:]
        draftLighting = Self.initialLighting
        restoreAppliedConfiguration()
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
        draftLighting = lightingBaseline
    }

    private func applyPendingLighting(through session: KeyboardSession) async throws {
        guard hasPendingLighting else { return }
        applyStep = .lighting
        let lighting = draftLighting
        try await session.applyLighting(lighting)
        recordApplied { $0.lighting = lighting }
        try await Task.sleep(for: Self.pauseBetweenOperations)
    }

    private func applyPendingKeymap(through session: KeyboardSession) async throws {
        guard !pendingKeyIDs.isEmpty else { return }
        applyStep = .keymap
        let actions = draftKeyActions
        try await session.applyKeymap(layout, actions: actions)
        recordApplied { $0.keyActions = actions }
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
    }

    func resetAllKeysToDefault() {
        draftKeyActions = [:]
    }

    /// Stores only real changes: the firmware default and an empty action both mean "no entry".
    private func setDraft(_ action: KeyAction, for key: KeyLayout.Key) {
        let isEmpty = action.modifiers.isEmpty && action.usage == 0
        let isDefault = action == .firmwareDefault(of: key)
        draftKeyActions[key.id] = isEmpty || isDefault || key.isFn ? nil : action
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
