import Foundation
import GK61Core
import GK61Storage
import Testing

@Suite("Saved configuration")
struct ConfigurationFileTests {
    @Test("A macro key survives save and load with its playback, events and delays")
    func roundTripsMacroKeys() throws {
        try withTemporaryDirectory { directory in
            let file = ConfigurationFile(url: directory.appending(path: "last-applied.json"))
            let macro = try Macro(playback: .repeatCount(3), steps: [
                MacroStep(.keyDown(usage: 0xE3), delayMilliseconds: 20),
                MacroStep(.keyUp(usage: 0xE3)),
                MacroStep(.mouseDown(.right), delayMilliseconds: 5),
                MacroStep(.mouseUp(.right)),
                MacroStep(.wheel(.down, notches: 2)),
            ])
            let configuration = AppliedConfiguration(
                keyActions: [21: .macro(macro), 63: .remap(toUsage: 0x04)], lighting: nil, appliedAt: nil)

            try file.save(configuration)

            #expect(try file.load() == configuration)
        }
    }

    @Test("A file saved before macros existed still loads its key remaps and lighting")
    func loadsThePreviousFormat() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appending(path: "last-applied.json")
            try Data("""
                {
                  "appliedAt" : "2026-11-27T19:05:45Z",
                  "keyActions" : { "63" : { "modifiers" : 1, "secondUsage" : 0, "usage" : 0 } },
                  "lighting" : { "brightness" : 4, "color" : { "palette" : { "_0" : 0 } }, "mode" : 6, "speed" : 0 }
                }
                """.utf8).write(to: url)

            let loaded = try ConfigurationFile(url: url).load()

            let ripple = try #require(LightingMode.named("Ripple"))
            #expect(loaded.keyActions == [63: .keys(modifiers: .leftControl, usage: 0, secondUsage: 0)])
            #expect(loaded.lighting == Lighting(mode: ripple, speed: 0, brightness: 4, color: .palette(.red)))
            #expect(loaded.appliedAt == Date(timeIntervalSince1970: 1_795_806_345))
        }
    }
}

/// Scratch files live in the system temporary directory, never in the worktree.
func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "gk61-storage-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}

@Suite("Macro library")
struct MacroLibraryFileTests {
    @Test("The library keeps each macro's id, name and steps in order")
    func roundTripsTheLibrary() throws {
        try withTemporaryDirectory { directory in
            let file = MacroLibraryFile(url: directory.appending(path: "macros.json"))
            let macros = [
                MacroDefinition(id: UUID(), name: "Copy", steps: [
                    MacroStep(.keyDown(usage: 0xE3)), MacroStep(.keyDown(usage: 0x06), delayMilliseconds: 30),
                    MacroStep(.keyUp(usage: 0x06)), MacroStep(.keyUp(usage: 0xE3)),
                ]),
                MacroDefinition(id: UUID(), name: "Scroll", steps: [MacroStep(.wheel(.up, notches: 3))]),
            ]

            try file.save(macros)

            #expect(try file.load() == macros)
        }
    }

    @Test("A missing library file loads as an empty library")
    func loadsNothingWhenMissing() throws {
        try withTemporaryDirectory { directory in
            let library = try MacroLibraryFile(url: directory.appending(path: "macros.json")).load()

            #expect(library.isEmpty)
        }
    }
}

@Suite("Macro key links")
struct MacroKeyLinkTests {
    @Test("The applied configuration remembers which library macro each macro key came from")
    func roundTripsMacroSources() throws {
        try withTemporaryDirectory { directory in
            let file = ConfigurationFile(url: directory.appending(path: "last-applied.json"))
            let macro = try Macro(playback: .untilReleased, steps: [MacroStep(.keyDown(usage: 0x04)), MacroStep(.keyUp(usage: 0x04))])
            let source = UUID()
            let configuration = AppliedConfiguration(
                keyActions: [21: .macro(macro)], macroSources: [21: source], lighting: nil, appliedAt: nil)

            try file.save(configuration)

            #expect(try file.load().macroSources == [21: source])
        }
    }
}
