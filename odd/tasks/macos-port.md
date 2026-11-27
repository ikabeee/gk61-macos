---
status: in-progress
---
# GK61 macOS port

Objective: native macOS replacement for the Windows "GK61 Driver" (OemDrv.exe v1.9) for VID 0x32E3 / PID 0x00F7.
Branch: `feat/macos-port`. Delivery: ask-on-risk. Test runner: Swift Testing (`swift test`).

## Specs

- S1. "Necesito un port para de esta aplicacion no hay versiones para macos" — port the GK61_Setup_v_1.9.exe configuration app to macOS.
- S2. Stack: "Native Swift/SwiftUI" (IOKit HID + SwiftUI).
- S3. UI: "Native macOS" — sidebar (Keys / Lighting / Macros / Device), system colors, light/dark mode, SF Symbols, interactive 61-key keyboard.
- S4. Location: "El port dejalo en mis repositories de documentos" → `~/Documents/REPOSITORIES/gk61-macos`.
- S5 (assumption). The port never sends firmware-update, bootloader or flash-erase commands.

## Tasks

| ID | Specs | Task | Route | Status | Evidence |
|----|-------|------|-------|--------|----------|
| T1 | S1, S2 | HID transport (IOKit, report 0x04, 64 B) + read-only probe CLI | inline | done | probe opened VID 0x32E3 PID 0xF7 fw 0x103, in/out 64/64, nothing sent |
| T2 | S1, S5 | Protocol spec from OemDrv.exe (docs/protocol.md) | delegated explorer (mapping trigger: >5 sequential disassembly lookups) | done | docs/protocol.md; parent spot check GetPSD bytes @0x4379f7 |
| T3 | S1 | Core: command framing + device info query | inline | done | RED→GREEN 3 tests; device replied PSD 0F 0B via probe |
| T4 | S1 | Core: layout resource + normal-layer key matrix (Fn layer left untouched in v1) | inline | done | RED→GREEN 6 tests (layout, matrix framing, modifier/key remap, applyKeymap) |
| T5 | S1 | Core: lighting modes, brightness, speed, colors | inline | pending | |
| T6 | S1 | Core: macros | inline | pending | |
| T7 | S2, S3 | SwiftUI app | inline | pending | |
| T8 | S2 | .app bundle packaging script | inline | pending | |

## Log

- L1 (2026-11-27) User request: "Necesito un port para de esta aplicacion no hay versiones para macos" (attached `~/Downloads/GK61_Setup_v_1.9.exe`).
- L2 Findings: Inno Setup 5.3.3 installer; variants per PID; user's board matches US / 00F7 / 00F7-2 variants. Vendor HID collection: usage page 0xFF00, report ID 0x04, 63-byte input + output payload. Lowerdev.dll is a thin HidD_* wrapper; protocol lives in OemDrv.exe. Existing GK6X tools target VID 0x1EA7, not this board.
- L4 Test seams agreed with the user: packet encoders, keyboard session (fake transport), layout loading. IOKit adapter is verified by hand with gk61-probe.
- L3 User choices: stack "Native Swift/SwiftUI"; UI "Native macOS"; location "El port dejalo en mis repositories de documentos".
- L5 Device check: GetPSD over IOHIDDeviceSetReport returned `A0 02 00 01 0F 0B …` → board matches the `00F7-2` Cfg (PSD 0x0f,0x0b). Use that Cfg for layout and LED options.
