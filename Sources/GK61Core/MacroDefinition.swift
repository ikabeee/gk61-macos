import Foundation

/// A named macro in the user's library. Keys play a copy of its steps with their own playback mode.
public struct MacroDefinition: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var steps: [MacroStep]

    public init(id: UUID = UUID(), name: String, steps: [MacroStep]) {
        self.id = id
        self.name = name
        self.steps = steps
    }
}
