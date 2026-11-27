import Foundation
import GK61Core

/// JSON file in Application Support with the user's macro library, saved whenever it changes.
public struct MacroLibraryFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static let standard = MacroLibraryFile(
        url: .applicationSupportDirectory.appending(path: "GK61/macros.json"))

    public func load() throws -> [MacroDefinition] {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        return try JSONDecoder().decode(SavedLibrary.self, from: Data(contentsOf: url)).macros.map { try $0.definition() }
    }

    public func save(_ macros: [MacroDefinition]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(SavedLibrary(macros: macros.map(SavedDefinition.init))).write(to: url, options: .atomic)
    }
}

private struct SavedLibrary: Codable {
    var macros: [SavedDefinition]
}

private struct SavedDefinition: Codable {
    var id: UUID
    var name: String
    var steps: [SavedMacroStep]

    init(_ definition: MacroDefinition) {
        id = definition.id
        name = definition.name
        steps = definition.steps.map(SavedMacroStep.init)
    }

    func definition() throws -> MacroDefinition {
        MacroDefinition(id: id, name: name, steps: try steps.map { try $0.step() })
    }
}
