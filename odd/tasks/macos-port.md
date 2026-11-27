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
- S6. Macros: "Wire up macros" with the "Library + assign" design — the Macros page holds named macros recorded by typing in the app, with editable steps and delays; the Keys inspector assigns a library macro to a key and picks how it repeats; one macro can go on several keys.
- S7. Macro keys survive save and reload: the applied configuration and the macro library persist to JSON without losing macros.
- S8. Test seams (user choice): "Recording → steps", "Saved-format round trip", "macOS key → HID table".

## Tasks

| ID | Specs | Task | Route | Status | Evidence |
|----|-------|------|-------|--------|----------|
| T1 | S1, S2 | HID transport (IOKit, report 0x04, 64 B) + read-only probe CLI | inline | done | probe opened VID 0x32E3 PID 0xF7 fw 0x103, in/out 64/64, nothing sent |
| T2 | S1, S5 | Protocol spec from OemDrv.exe (docs/protocol.md) | delegated explorer (mapping trigger: >5 sequential disassembly lookups) | done | docs/protocol.md; parent spot check GetPSD bytes @0x4379f7 |
| T3 | S1 | Core: command framing + device info query | inline | done | RED→GREEN 3 tests; device replied PSD 0F 0B via probe |
| T4 | S1 | Core: layout resource + normal-layer key matrix (Fn layer left untouched in v1) | inline | done | RED→GREEN 6 tests (layout, matrix framing, modifier/key remap, applyKeymap) |
| T5 | S1 | Core: lighting modes, brightness, speed, colors | inline | done | RED→GREEN 5 tests (mode catalog 1–31, palette/rainbow byte, per-key custom modes, applyLighting) |
| T6 | S1, S5 | Core: macros | delegated writer (parallel units, disjoint surfaces) | done | 13 rules RED→GREEN; swift test 27/27; parent spot check A8 seq=i+1 @0x4382b3 |
| T7 | S2, S3 | SwiftUI app | delegated writer (parallel units, disjoint surfaces) | done | 7961f8e; build 0 warnings; parent viewed Keys/inspector, Lighting, Device in the packaged app; Apply never pressed |
| T8 | S2 | .app bundle packaging script | delegated with T7 | done | 7961f8e; scripts/build-app.sh → build/GK61.app, codesign verify ok |
| T9 | S6, S8 | Core: recorded key events → macro steps with delays | inline | done | RED→GREEN 5 rules (gap delays, 16-bit clamp, auto-repeat, orphan release, release held keys); swift test 33/33 |
| T10 | S6, S8 | HID: macOS key code → HID usage table | inline | done | RED→GREEN: 10 sampled keys + Fn has none; GK61HIDTests target |
| T11 | S7, S8 | Storage module: applied config + macro library JSON round trip | inline | done | RED (macro lost on save) →GREEN; library + key-link round trips; previous-format file pinned; 5 storage tests |
| T12 | S6, S7 | App: macro library store, Macros page, recording, key assignment | inline | pending | |

## Log

- L1 (2026-11-27) User request: "Necesito un port para de esta aplicacion no hay versiones para macos" (attached `~/Downloads/GK61_Setup_v_1.9.exe`).
- L2 Findings: Inno Setup 5.3.3 installer; variants per PID; user's board matches US / 00F7 / 00F7-2 variants. Vendor HID collection: usage page 0xFF00, report ID 0x04, 63-byte input + output payload. Lowerdev.dll is a thin HidD_* wrapper; protocol lives in OemDrv.exe. Existing GK6X tools target VID 0x1EA7, not this board.
- L4 Test seams agreed with the user: packet encoders, keyboard session (fake transport), layout loading. IOKit adapter is verified by hand with gk61-probe.
- L3 User choices: stack "Native Swift/SwiftUI"; UI "Native macOS"; location "El port dejalo en mis repositories de documentos".
- L5 Device check: GetPSD over IOHIDDeviceSetReport returned `A0 02 00 01 0F 0B …` → board matches the `00F7-2` Cfg (PSD 0x0f,0x0b). Use that Cfg for layout and LED options.
- L6 Packaged GK61.app needs its own Input Monitoring grant (the Terminal's grant doesn't carry over). Macros page is a placeholder until T6 lands; the app's saved-config format doesn't yet store macro actions.
- L7 12ea309 (macros) review assess: medium, review_due=false (under_budget) — pending in the open slice. App saved-config format does not store macro actions yet; Macros page still a placeholder.
- L8 (2026-11-27) User report: "no lo detecta" (Device page: "Needs Input Monitoring"). Cause: TCC stored the grant with the ad-hoc cdhash of an earlier build; every rebuild changes it. Fix 66dbb4f: self-signed "GK61 Local Signing" identity (scripts/create-signing-identity.sh), build-app.sh signs with it; designated requirement is now `identifier "local.gk61.config" and certificate leaf = H"bf8a5dc2…"`. Stale record reset with `tccutil reset ListenEvent local.gk61.config` (user-approved), user re-enabled it. Verified in the app: "GK61 Gaming Keyboard connected", PID 0x00F7, firmware 1.03, PSD 0F 0B. "1 unapplied change" is a lighting draft edited in the UI (Ripple), not a defect. Nothing written to the keyboard. Next: user decides whether to test Apply on the real keyboard or wire macros into the UI.
- L9 (2026-11-27) First real write, user-authorized ("Test Apply"): lighting only, Ripple / speed 0 / brightness 4 / red → SetLED `AE 01 00 00 06 00 04 01`, acknowledged by `AE`; last-applied.json saved 19:03:15Z. User confirmed on the keyboard: "Yes, red ripple". SetLED encoding (paletteOrRainbow = index + 1) verified on hardware. Keymap and macro writes still untested on hardware.
- L10 (2026-11-27) Keymap write (CapsLock→LCtrl, normal table only) was acknowledged; user first reported "No, still CapsLock". Disassembly (`0x40918c`–`0x4096f3`) shows Windows always sends the Fn table after the normal one; fix f86be76 sends both. Later the user reported "necesito el capslock" and "no me sirve el capslock"; no macOS remap was active (hidutil UserKeyMapping null), so the earlier write likely took effect late. Restored with a factory keymap (normal + default Fn tables) at 19:15:20Z; pending user confirmation that CapsLock works.
- L11 (2026-11-27) User confirmed after the factory keymap write: "Yes, it works" (CapsLock restored). A normal + Fn table write changes the keymap on hardware. A remap to a non-default key with the fixed sequence is still untested; the user asked to leave CapsLock alone.
- L12 (2026-11-27) User: "Wire up macros"; design "Library + assign (Recommended)"; test seams "Recording → steps", "Saved-format round trip", "macOS key → HID table". Route: inline, sequential units (no writer trigger: units depend on each other through Package.swift and the store). Hardware macro test needs a separate go-ahead; never on CapsLock.
