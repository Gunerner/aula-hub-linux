# aula-hub-linux

Run the official **AULA Hub** keyboard app natively on Linux. No Wine and no VM.

> **Unofficial.** Not affiliated with or endorsed by AULA. This repository contains
> no AULA software: it patches the official installer on your machine. Use at your
> own risk.

AULA Hub is an Electron app that talks to the keyboard over WebHID, so it can run on
Linux's Electron. Out of the box, though, it doesn't see the keyboard. When it does,
settings fail with "Configuration table is incorrect". This project fixes both.

## Tested hardware

| Device | USB ID | Status |
|---|---|---|
| BY Tech Gaming Keyboard (detected as AULA F75, uuid `0300000000cd`), wired | `258a:010c` | Lighting effect, brightness and speed work |
| Compx 2.4G Wireless Receiver | `3554:fa09` | Detected; not tested with the keyboard in 2.4G mode |

Tested on CachyOS (Arch) with KDE Wayland and Electron 40.10.

**Not tested:** custom/per-key lighting and the color picker (they use a different
write command), key remapping, macros and performance settings. Headset features
(Windows-only C-Media service) and game integration don't work on Linux.

## Requirements

- `electron40`, `7zip` (provides `7z`), `python`, `nodejs` + `npm` (for `npx`), `util-linux` (`unshare`)
- The **AULA Hub 1.1.22** Windows installer, `Aula Hub Setup 1.1.22.exe`
  (SHA-256 `3c03c0a1e53c72ad6ab95e7749dc40f62a6f18e40d7a07d993c5f2bd7d3b77c6`).
  AULA's server no longer lists a download link for 1.1.22, so you need your own
  copy. Other versions are rejected (see [Why 1.1.22](#why-1122)).

On Arch: `sudo pacman -S --needed electron40 7zip python nodejs npm`

## Install

```sh
./install.sh "/path/to/Aula Hub Setup 1.1.22.exe" --udev
```

The script:

1. Verifies the installer's checksum.
2. Unpacks it with 7-Zip and `@electron/asar`. Nothing from the installer is executed.
3. Applies the patches in [`patches/`](patches/) and installs to `~/.local/share/aula-hub-linux`.
4. Adds an `aula-hub` launcher in `~/.local/bin` and an app-menu entry.
5. With `--udev`, installs a udev rule (asks for sudo) that gives your user access to
   **only** the two devices above. Without `--udev`, it prints the command to run.

Uninstall: `./uninstall.sh`. App settings in `~/.config/aula-hub` are kept.

## Use

```sh
aula-hub                 # offline (default)
AULA_ONLINE=1 aula-hub   # allow network
```

The launcher runs the app in a private network namespace with no network access.
The app then can't download firmware or remote UI updates, while keyboard settings
still work because they go over USB.

**Never use the firmware/version page.** These patches were only verified for
settings writes, never for firmware.

## What the patches fix

1. **Device names** ([`patches/hid-name-fix.js`](patches/hid-name-fix.js)).
   Linux names HID devices `<Manufacturer> <Product>` ("BY Tech Gaming Keyboard"),
   while Windows reports only the product ("Gaming Keyboard"). AULA Hub matches exact
   names, so it silently ignored the keyboard. The fix strips the prefix. AULA's
   web driver has the same issue in Chrome on Linux.

2. **Firmware layout** ([`patches/apply.py`](patches/apply.py)). Before reading or
   writing lighting, the SDK looks for an `ff ff` marker in front of the per-mode
   lighting table. This keyboard's firmware has `80 f0` there instead. The patch
   accepts `80 f0` **only** at that exact position (profile offset 56). Every other
   layout behaves as before.

3. **Value ranges**. The app's sliders go up to 20, but this keyboard stores
   brightness 0–9 and speed 0–4. The sliders are limited to those ranges, so the app
   only writes values the keyboard also produces itself through its Fn keys.

### Profile layout (feature report 6, read command `0x84`, 128 bytes)

Found by changing settings with the keyboard's own Fn keys and diffing the
profile read-only before anything was written:

| Offset | Meaning |
|---|---|
| 10 | Current lighting mode |
| 56–57 | `80 f0` marker (the app expects `ff ff`) |
| 58 + (mode − 1) × 2 | Brightness of that mode (0–9) |
| 59 + (mode − 1) × 2 | Speed (high nibble, 0–4), color type (low nibble) |
| 126–127 | `5a a5` trailer |

Known quirk: the app only writes color type 0 or 7, while the keyboard also uses
2, 4, 5 and 6. Editing an effect in the app can therefore change its colors. This is
harmless and can be reset from the keyboard.

## Why 1.1.22

AULA Hub 2.2.3 (October 2026) has the same firmware-layout problem, but its code is
heavily obfuscated, so the patches haven't been ported. 1.1.22's SDK is readable, and
each patch is a single exact match that fails loudly if anything differs.

## License

The scripts and patches in this repository are MIT licensed (see [LICENSE](LICENSE)).
AULA Hub itself is proprietary software owned by AULA. It is not included here and
not covered by this license.
