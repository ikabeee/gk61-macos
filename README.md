# GK61 for macOS

A native macOS app (Swift, SwiftUI, IOKit HID) that configures the GK61 keyboard.
It replaces the Windows-only "GK61 Driver" (`OemDrv.exe` v1.9), which has no macOS version.

## Supported device

| Property | Value |
|---|---|
| Vendor ID | `0x32E3` |
| Product ID | `0x00F7` |
| Firmware tested | `0x0103` |
| Signature (PSD) | `0F 0B` |

The app refuses to write to a keyboard that reports a different signature.

## Build and run

Requirements: macOS 15 or later, Xcode with Swift 6.2 or later.

```sh
swift run GK61            # run from the package
scripts/create-signing-identity.sh  # once per Mac: local code-signing identity
scripts/build-app.sh                # build build/GK61.app (release)
open build/GK61.app
```

`scripts/build-app.sh` builds the `GK61` product in release mode, then copies the SwiftPM resource
bundle into `Contents/Resources` so the key layout loads. Set `SCRATCH_PATH` to use a build
directory other than `.build`.

The app is signed with the self-signed "GK61 Local Signing" identity from
`scripts/create-signing-identity.sh`. macOS ties the Input Monitoring grant to the app's code
signature; an ad-hoc signature changes on every build and silently drops the grant, while this
identity keeps it. Without the identity the script falls back to ad-hoc signing and warns.

`gk61-probe` is a command-line check that opens the keyboard and sends only the read-only
signature query:

```sh
swift run gk61-probe
```

## Input Monitoring permission

The keyboard's configuration channel shares its USB interface with the keyboard itself, and macOS
only lets apps open keyboard interfaces with **Input Monitoring** access. On first launch macOS asks
for it. If you denied it, open **System Settings › Privacy & Security › Input Monitoring**, turn on
GK61 (or the terminal you ran `swift run` from), then click **Reconnect**. If it still fails, quit
and reopen the app. The Device page has a button that opens that settings pane.

If GK61 is switched on there but the app still asks for access, the grant belongs to an older
signature. Reset it, then reopen the app and allow it again:

```sh
tccutil reset ListenEvent local.gk61.config
```

## What it does

- **Keys**: click a key on the drawn keyboard to remap it to any HID keyboard key, with optional
  held modifiers for combinations (for example ⌘C). Each key can go back to its default. The Fn
  key and the Fn layer are left unchanged.
- **Lighting**: all 31 backlight modes, with speed (when the mode has one), brightness, palette
  colors or rainbow, and per-key colors for the seven custom modes.
- **Device**: connection status, product name, IDs, firmware version and signature.
- **Macros**: not available yet.

Edits stay pending until you click **Apply** (⌘S); **Revert** discards them. Apply writes only
what changed, lighting first and then the keymap, as the Windows driver does.

## Things to know

- **No read-back.** The keyboard has no command that reports its current keymap or lighting. The
  app shows what this Mac last applied, saved in
  `~/Library/Application Support/GK61/last-applied.json`. Changes made with other software, the
  keyboard's Fn shortcuts, or another computer are not visible.
- **Writes are persistent.** Applied settings stay on the keyboard after you unplug it.
- **No firmware commands.** The app never sends firmware-update or bootloader commands.

## Protocol

The wire protocol, reverse-engineered from the Windows driver, is documented in
[docs/protocol.md](docs/protocol.md).
