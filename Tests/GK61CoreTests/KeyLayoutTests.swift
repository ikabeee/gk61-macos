import GK61Core
import Testing

@Suite("Layout loading")
struct KeyLayoutTests {
    @Test("The bundled GK61 layout has 61 keys with the Cfg matrix indices and HID usages")
    func loadsKeysFromCfg() throws {
        let layout = try KeyLayout.gk61()

        #expect(layout.keys.count == 61)
        #expect(layout.key(labeled: "Esc")?.matrixIndex == 21)
        #expect(layout.key(labeled: "Esc")?.defaultUsage == 0x29)
        #expect(layout.key(labeled: "LCtrl")?.matrixIndex == 105)
        #expect(layout.key(labeled: "LCtrl")?.defaultUsage == 0xE0)
    }

    @Test("The Fn key is marked as Fn and has no HID usage")
    func marksFnKey() throws {
        let fn = try #require(try KeyLayout.gk61().key(labeled: "Fn"))

        #expect(fn.isFn)
        #expect(fn.matrixIndex == 118)
        #expect(fn.defaultUsage == nil)
    }
}
