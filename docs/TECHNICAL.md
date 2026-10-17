# Technical details

## How it works

AULA Hub is an Electron app that talks to the keyboard over WebHID, a Chromium API,
so it can run on Linux's Electron. `install.sh` does the following:

1. Verifies the installer's SHA-256 (`3c03c0a1…77c6`, AULA Hub 1.1.22).
2. Unpacks the NSIS installer and its `app-64.7z` with 7-Zip, then unpacks `app.asar`
   with [`patches/asar_extract.py`](../patches/asar_extract.py). Its output is
   byte-identical to `@electron/asar`. Nothing from the installer is executed.
3. Applies [`patches/apply.py`](../patches/apply.py). Each rule must match exactly
   once, or the script stops without writing anything. Originals are kept as `*.orig`.
4. Uses the system `electron40` if there is one (Arch). Otherwise it downloads the
   official Electron 40.10.4 from GitHub and verifies it against `SHASUMS256.txt`.

The launcher runs the app with `unshare --user --map-current-user --net`, a private
network namespace with no interfaces. The app cannot reach the internet, so it
cannot download firmware or UI hot-updates. `AULA_ONLINE=1` skips this.

On Ubuntu 24.04+, `kernel.apparmor_restrict_unprivileged_userns=1` blocks user
namespaces. `--system` then installs an AppArmor profile that allows `userns` for the
downloaded Electron binary and for `/usr/bin/unshare`.

## Files and permissions

Everything `install.sh` writes outside the project folder:

| Path | When | What |
|---|---|---|
| `~/.local/share/aula-hub-linux/app/` | always | Patched app (originals kept as `*.orig`) |
| `~/.local/share/aula-hub-linux/icons/` | always | App icons from the installer |
| `~/.local/share/aula-hub-linux/electron/` | no system `electron40` | Official Electron 40.10.4 |
| `~/.local/bin/aula-hub` | always | Launcher |
| `~/.local/share/applications/aula-hub.desktop` | always | App-menu entry |
| a `mktemp -d` folder | always | Scratch space, deleted on exit, even on failure |
| `/etc/udev/rules.d/70-aula-hub.rules` | `--system` | Device access (below) |
| `/etc/apparmor.d/aula-hub-linux` | `--system`, and only if `kernel.apparmor_restrict_unprivileged_userns=1` (Ubuntu 24.04+) | Allows user namespaces for the downloaded Electron and `/usr/bin/unshare` |

The app itself stores its settings and logs in `~/.config/aula-hub/`.

Every `sudo` call, all of them only with `--system`:

```sh
sudo install -m 644 files/70-aula-hub.rules /etc/udev/rules.d/70-aula-hub.rules
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hidraw      # re-applies rules to hidraw devices
sudo tee /etc/apparmor.d/aula-hub-linux            # Ubuntu 24.04+ only
sudo apparmor_parser -r /etc/apparmor.d/aula-hub-linux   # Ubuntu 24.04+ only
```

**The udev rule** ([`files/70-aula-hub.rules`](../files/70-aula-hub.rules)) tags
hidraw nodes with `uaccess`, so systemd-logind gives the user at the active seat an
ACL on them. It sets no `MODE` or `GROUP`, so nothing becomes world-writable. It
matches only:

- USB `258a:010c` (keyboard) and `3554:fa09` (receiver)
- **and** USB interface 1, the vendor configuration channel (usage page `0xFF00` /
  `0xFF02`)

Interface 0 is the normal typing channel. It's deliberately excluded, so other
programs running as you can't read raw keystrokes through it. Because `idVendor` and
`bInterfaceNumber` live on different parent devices (and one udev rule line can only
match a single parent), the rule first marks the device with `ENV{AULA_HUB_DEVICE}`
and then checks the interface.

## The patches

1. **Device names** ([`hid-name-fix.js`](../patches/hid-name-fix.js)). Linux names HID
   devices `<Manufacturer> <Product>` ("BY Tech Gaming Keyboard"), while Windows
   reports only the product ("Gaming Keyboard"). AULA Hub compares exact names
   (`pName.includes(productName)`), so it silently ignored the keyboard. The fix
   overrides `HIDDevice.prototype.productName` to strip `BY Tech ` / `Compx `.
   AULA's web driver has the same issue in Chrome on Linux.

2. **Firmware layout.** Before reading or writing lighting, the SDK looks for an
   `ff ff` marker in front of the per-mode lighting table, and fails with
   "Configuration table is incorrect" when it's missing. This keyboard's firmware
   has `80 f0` there. The patch accepts `80 f0` **only** at profile offset 56.

3. **Value ranges.** The lighting page's sliders go to 20 (`maxLightly:21`,
   `maxSpeed:21`). The keyboard stores brightness 0–9 and speed 0–4, as measured
   with its own Fn keys. The sliders are limited to 10 and 5 steps.

## Profile layout

Feature report 6. The app sends `84 00 00 01 00 80 00` (padded to 519 bytes); the
reply is report ID, a 7-byte header and 128 profile bytes:

| Offset | Meaning |
|---|---|
| 10 | Current lighting mode |
| 56–57 | `80 f0` marker (the app expects `ff ff`) |
| 58 + (mode − 1) × 2 | Brightness of that mode (0–9) |
| 59 + (mode − 1) × 2 | Speed (high nibble, 0–4), color type (low nibble) |
| 126–127 | `5a a5` trailer |

The app writes the profile back with `04 00 00 01 00 80 00` + 128 bytes.

The layout was found read-only: settings were changed with the keyboard's Fn keys
and the profile was diffed before and after. Then single app writes were verified
by reading the profile back. Each one changed only the expected byte.

Known quirk: the app writes color type 0 or 7 only, while the keyboard also uses 2,
4, 5 and 6, so editing an effect in the app can change its colors.

## Why 1.1.22 and not 2.2.3

AULA Hub 2.2.3 (October 2026, Electron 41) has the same firmware-layout check, but
its code is heavily obfuscated (encrypted string tables), so the patches haven't
been ported. In 1.1.22 the SDK is readable, and every patch is an exact,
single-match replacement.

## Not working on Linux

- Headset features: they depend on a Windows-only C-Media service (`HeadsetService.exe`).
- Game integration: a Windows Python helper (`aula-gsi.exe`).
- Firmware updates: intentionally blocked by offline mode. Don't try them.
