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
| `A0 02 03` | "ResetMatrix" (Windows log name); see Apply order | none | Purpose unconfirmed [I] |
| `A0 02 04 seq 0E A5 <54 B> … [60]=A5` | Write normal-layer key matrix, packet `seq` = 1…14 | `A0` each | 14 × 54 B = 756 B |
| `A0 02 05 …` | Write Fn-layer key matrix | `A0` each | Same layout as `A0 02 04` |
| `AE 01 00 00 mode speed bright color [7]=… [8..]` | Set backlight | `AE` | Per-key data for custom modes, see below |
| `AE 07 00 00 mode speed bright` | Set side light | `AE` | |
| `AA 00` | Free all macro buffers | `AA` | Persistent (`0x438190`) |
| `A7 id sizeHi sizeLo` | Allocate macro buffer `id`, size = body length + 5 (big-endian) | `A7` | `0x4380e0` |
| `A8 id 00 seq total len <≤57 B>` | Write one chunk of the macro body, data at offset 6 | `A8` each | `0x438220`, see Macro upload |
| `A6 02 01` / `A6 02 00` | Sent when macro recording starts / stops | none | Purpose [I] |
| **`A5 01 00`** | **Enter bootloader** | sync read | **Never send.** Used only by the firmware updater |

No read-back, profile, or factory-reset command exists. The Windows app keeps profiles on the host. [V]

The Apply order (`fcn.00408ea0`) is:

1. backlight;
2. side light;
3. macros, if any key uses one (`AA`, then `A7` and `A8…` per macro key, see Macro upload), then the normal matrix, then the Fn matrix;
4. `A0 02 03`, only when the caller sets flag `0x100` (`0x409724`; sent without waiting for a reply). Its purpose is unconfirmed [I].

The keys flag (`0x408f8c`: `test bl, 1`) always writes both tables, normal then Fn, 50 ms apart (`0x4096b2`–`0x4096f3`).
Keys without an Fn function get `[index, 00 00 00 00, 00]` in the Fn table (`fcn.00408770`). Verified on the
GK61 (PID 0x00F7, fw 1.03): a normal table sent alone is acknowledged but has no effect. [V]

## Key matrix [V]

- 756 bytes = 126 entries × 6 bytes. The entry at `index × 6` is `[index, c1, c2, c3, c4, 0x00]`.
- Unused slots are all zero.
- `index` is the 4th number of a Cfg `[KEY]` line. For the GK61, `index = row × 21 + col` [I] (Esc = 21, Tab = 42, Caps = 63, LShift = 84, LCtrl = 105).
- Code bytes `c1…c4`:

| Meaning | c1 c2 c3 c4 |
|---|---|
| Firmware default (key unchanged, or the Fn key) | `00 00 00 00` |
| Key or combo | `FC modmask hid1 hid2` |
| Macro, see Macro key entry | `F3 id countHi countLo` / `F0 id 00 00` / `F1 id 00 00` |
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

Serialized by `fcn.00408860` into a 512-byte buffer with no bounds check (the port rejects longer bodies).
Byte 0 is `01`, bytes 1–30 are zero, and events start at byte 31. There is no terminator; the body length
travels in `A7`. Every event is followed by `01 hi lo` when its delay is nonzero (milliseconds, the low
16 bits of the stored value).

| Event | Bytes | Evidence |
|---|---|---|
| Key down / up | `02 hid` / `03 hid`; modifiers as HID `E0`–`E7` | `0x4089f8`: `(flag == 0) + 2`; the recorder marks key down 1 and key up 0 (`0x41886b`, `0x415d83`), and the macro list shows the same down icon for a nonzero stored flag (`0x417f55`) |
| Mouse button down / up | `04 n` / `05 n`; n = 1 left, 2 right, 3 middle | `0x408929`, same flag rule |
| Wheel up / down | `08 00` / `09 00`, repeated once per notch | `0x408948`; "Scroll Up" is pseudo-key `F5` → `08`, "Scroll Down" `F6` → `09` (`0x424bd6`, `0x424c47`) |
| Delay | `01 hi lo` | `0x408961` |
| Mouse move [I] | `06 xh xl ? ?` | `0x408a1b` writes bits 16–23 and 8–15 of the stored dword as the last two bytes, which does not look like a separate Y. Not supported by the port |

Windows records virtual-key codes and maps them to HID usages here; the port records HID usages directly.

## Macro key entry [V]

A key that plays a macro has code bytes built by `fcn.004082c0` (type 5, `0x4084e6`) from the macro's loop mode.
`id` is `00` in the stored table and is patched to the buffer id during Apply (`0x409500`).

| Loop mode (macro dialog, saved at `0x414893`) | Mode | c1 c2 c3 c4 |
|---|---|---|
| "Specified cycle times" | 0 | `F3 id countHi countLo`; count is a 16-bit value, an empty or zero entry is saved as 1 |
| "Cycle until the key pressed again" | 1 | `F1 id 00 00` |
| "Cycle until the key released" | 2 | `F0 id 00 00` |

`F2` is never produced.

## Macro upload [V]

During Apply (`fcn.00408ea0`), the driver counts entries with c1 in `F0`…`F3` in both layers. If any exist:

1. `AA 00`, then 100 ms;
2. for each matrix index 0…125, the normal-layer entry and then the Fn-layer entry: if it is a macro key,
   serialize its macro, send `A7 id size`, wait 50 ms, send the `A8` chunks, wait 50 ms, and patch `id` into c2;
3. write the matrices.

- Buffer ids start at 1 and grow by one per **macro key**. Keys that share a macro each get their own buffer and their own upload.
- `A7` size = body length + 5, big-endian (`0x438109`).
- `A8` chunks: `[A8, id, 00, seq, total, len, data…]` with `seq` = 1…total, `total` = ceil(body length / 57),
  `len` = the length of **this** chunk (57, or the remainder in the last chunk), and data at payload offset 6
  (`0x4382ab`–`0x4382e2`). Each chunk waits for the `A8` acknowledgement, then 30 ms.
- With no macro keys, no macro command is sent, so buffers from an earlier Apply presumably stay allocated [I].

The port uploads normal-layer macro keys only (the Fn layer takes key actions, never macros), paces with the acknowledgements,
30 ms after each chunk, and 100 ms after `AA` and after each macro.

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
