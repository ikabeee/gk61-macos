# GK61 (VID 0x32E3) configuration protocol

Reverse-engineered statically from the Windows driver `OemDrv.exe` shipped in `GK61_Setup_v_1.9.exe`
(build used by the `00F7` / `00F7-2` variants; the `US` build has an identical wire format).
Addresses are radare2 virtual addresses in that build. **[V]** verified from code, **[I]** inferred.

## Transport

- HID interface whose collection has usage page `0xFF00`, usage `0x00`, and 64-byte input and output reports. [V]
- Every command is **one Output report, ID `0x04`, 64 bytes**: `[0x04, payload[0..62]]`, zero-padded.
  Windows sends it with `WriteFile` (`0x401066`); on macOS `IOHIDDeviceSetReport(kIOHIDReportTypeOutput, 4, …)` reaches the device (verified with GetPSD). [V]
- Replies arrive as Input reports, ID `0x04`; the payload starts after the ID byte. [V]
- There is **no checksum**. [V]
- Feature reports and `GetInputReport` are never used. [V]
- Firmware version = USB `bcdDevice` (`kIOHIDVersionNumberKey`). [V]

Below, offsets are **payload** offsets (report byte = offset + 1).

## Acknowledgement and timing [V]

- Before each send, pending replies are discarded.
- After the send, the driver waits up to ~2 s (101 × 20 ms) for a reply whose `payload[0]` equals the command byte (`fcn.004378c0`).
- On timeout it shows "Wait timeout for cmd 0x%X", carries on, and never checks status bytes.
- For replies to `A0`, the driver keys on `A0, p[4], p[5], p[6]`; for every other command, on `p[0..3]`.
- Pacing:
  - 20 ms after every write;
  - 30 ms after each acknowledged chunk;
  - 50–100 ms between operations of one Apply.

## Commands

| Payload | Purpose | Ack | Notes |
|---|---|---|---|
| `A0 02 00 01` | Get PSD (read-only) | `A0` | Reply echoes bytes 0–3, PSD at `p[4], p[5]`, rest zero. Observed on PID 0x00F7 fw 0x103: `0F 0B` (= `00F7-2` Cfg) |
| `A0 02 03` | Reset key matrix to factory | none | Persistent |
| `A0 02 04 seq 0E A5 <54 B> … [60]=A5` | Write normal-layer key matrix, packet `seq` = 1…14 | `A0` each | 14 × 54 B = 756 B |
| `A0 02 05 …` | Write Fn-layer key matrix | `A0` each | Same layout as `A0 02 04` |
| `AE 01 00 00 mode speed bright color [7]=… [8..]` | Set backlight | `AE` | Per-key data for custom modes, see below |
| `AE 07 00 00 mode speed bright` | Set side light | `AE` | |
| `AA 00` | Free all macro buffers | `AA` | Persistent |
| `A7 id sizeHi sizeLo` | Allocate macro buffer, size = len + 5 (big-endian) | `A7` | |
| `A8 id 00 seq total len <≤57 B>` | Write macro data at offset 6; total = ceil(len / 57) | `A8` each | |
| `A6 02 01` / `A6 02 00` | Sent when macro recording starts / stops | none | Purpose [I] |
| **`A5 01 00`** | **Enter bootloader** | sync read | **Never send.** Used only by the firmware updater |

No read-back, profile, or factory-reset command exists. The Windows app keeps profiles on the host. [V]

The Apply order (`fcn.00408ea0`) is:

1. backlight;
2. side light;
3. macros, if any key uses one (`AA`, then `A7` and `A8…` per macro), then the normal matrix, then the Fn matrix;
4. reset matrix.

## Key matrix [V]

- 756 bytes = 126 entries × 6 bytes. The entry at `index × 6` is `[index, c1, c2, c3, c4, 0x00]`.
- Unused slots are all zero.
- `index` is the 4th number of a Cfg `[KEY]` line. For the GK61, `index = row × 21 + col` [I] (Esc = 21, Tab = 42, Caps = 63, LShift = 84, LCtrl = 105).
- Code bytes `c1…c4`:

| Meaning | c1 c2 c3 c4 |
|---|---|
| Firmware default (key unchanged, or the Fn key) | `00 00 00 00` |
| Key or combo | `FC modmask hid1 hid2` |
| Macro (mode 0 / 1 / 2) | `F3` / `F1` / `F0`, buffer id, macro fields [I] |
| Mouse functions [I] | `B0 B2 B1 B3 B4` … |
| Media / system [I] | `A0 93 94 95 96 90 91 92`, `A1`–`AA` |

Modifier mask bits:

| Key | Bit | Key | Bit |
|---|---|---|---|
| LCtrl | `01` | RCtrl | `10` |
| LShift | `02` | RShift | `20` |
| LAlt | `04` | RAlt | `40` |
| LGUI | `08` | RGUI | `80` |

The Fn layer uses the same encoding and indices.

## Macro body [V]

Maximum 512 bytes. Byte 0 is `01`, bytes 1–30 are zero, and events start at byte 31:

| Event | Bytes |
|---|---|
| Key down / up | `02 hid` / `03 hid` (modifiers as HID `E0`–`E7`) |
| Mouse button down / up | `04 n` / `05 n` (n = 1 left, 2 right, 3 middle) |
| Wheel up / down | `08 00` / `09 00` |
| Delay | `01 hi lo` (ms), after any event with a nonzero delay |
| Mouse move [I] | `06 xh xl yh yl` |

## Backlight [V]

- `mode` is the hardware mode number, 1…31.
- `speed` and `bright` take levels `0…4` [I]: Cfg has `SpeedNum=5`, and brightness has five levels too.
- `color` is the index into the default palette:

  | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
  |---|---|---|---|---|---|---|
  | red | green | blue | yellow | magenta | cyan | white |

  Modes whose Cfg `LedOpt` field 4 is 8 or 9 use `0` = rainbow and index + 1 for a fixed color.
- Custom modes (hardware `0x19`–`0x1F`): every packet repeats `AE 01 00 00 mode speed bright` with `[7] = FF`, and bytes 8…59 carry 13 entries `[slot | 0x80, R, G, B]`. All 126 matrix slots are sent in order (slots without a key are black), then an `FF` terminator: 505 bytes over 10 packets, each acknowledged by `AE` (`0x408fc0`–`0x409042`). [V]

## Firmware update (out of scope)

- `A5 01 00` switches the MCU to its bootloader. The Windows app then loads `Update\%04x\ota_usb_boot.dll!DfuUpdataFirmware`.
- No update image ships in this installer.
- The port must never send `A5`.
