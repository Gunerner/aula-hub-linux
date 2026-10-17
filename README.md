# AULA Hub for Linux

Use the official **AULA Hub** keyboard app on Linux to change your keyboard's lighting
effect, brightness and speed. No Windows, no Wine and no virtual machine needed.

> ⚠️ **Unofficial project.** Not made or supported by AULA. It does **not** include
> AULA's app: you supply the official installer, and this project adapts it for Linux
> on your own computer. Use at your own risk.

## Will it work for me?

It's tested with this hardware:

| Device | What Linux calls it | Status |
|---|---|---|
| AULA keyboard (F75 family), **wired** | `BY Tech Gaming Keyboard` (`258a:010c`) | ✅ Lighting effect, brightness and speed work |
| AULA 2.4G USB receiver | `Compx 2.4G Wireless Receiver` (`3554:fa09`) | Detected, not tested yet |

To check your keyboard, open a terminal and run `lsusb`. You should see a line with
`258a:010c` in it.

Installs tested on Arch / CachyOS (used daily), Debian 12, Ubuntu 24.04 and Fedora 41.
It should work on other distros from those families too: Linux Mint, Pop!_OS, Manjaro,
EndeavourOS, Nobara and so on. You need a 64-bit Intel/AMD PC.

---

## Install, step by step

You'll paste a few commands into a **terminal**. Open one from your app menu (search
for "Terminal"). To paste into a terminal, use **Ctrl + Shift + V**.

### Step 1: Install the tools it needs

Pick the line for your Linux, paste it and press Enter. It asks for your password,
and nothing is shown while you type it. That's normal.

**Ubuntu, Linux Mint, Pop!_OS, Debian, Zorin, elementary** (anything that uses `apt`):
```sh
sudo apt update && sudo apt install -y 7zip python3 curl
```
On older versions where `7zip` isn't found (Debian 11, Ubuntu 22.04, Mint 21), use:
```sh
sudo apt update && sudo apt install -y p7zip-full python3 curl
```

**Fedora, Nobara** (anything that uses `dnf`):
```sh
sudo dnf install -y p7zip p7zip-plugins python3 curl
```

**Arch, CachyOS, Manjaro, EndeavourOS** (anything that uses `pacman`):
```sh
sudo pacman -S --needed 7zip python curl electron40
```

### Step 2: Get the AULA Hub 1.1.22 installer

You need the Windows installer file **`Aula Hub Setup 1.1.22.exe`**. Put it in your
**Downloads** folder.

Only version **1.1.22** works (see [Why 1.1.22](docs/TECHNICAL.md#why-1122-and-not-223)).
AULA's website now offers a newer version, so you may have to ask AULA support or
find an old copy. The install script checks that it's the right file, so a wrong
one does no harm.

### Step 3: Download this project

```sh
cd ~/Downloads && curl -L https://github.com/Gunerner/aula-hub-linux/archive/refs/heads/main.tar.gz | tar xz
```

### Step 4: Install

```sh
cd ~/Downloads/aula-hub-linux-main && ./install.sh ~/Downloads/"Aula Hub Setup 1.1.22.exe" --system
```

This takes a minute or two. On Ubuntu, Debian and Fedora it downloads Electron
(about 110 MB, the engine the app runs on). At the end it asks for your password once,
to let your user talk to the keyboard. When you see **Done!**, it's installed.

### Step 5: Open it

Find **AULA Hub** in your app menu. Make sure the keyboard is plugged in **with the cable**.

You can now delete the `aula-hub-linux-main` folder from Downloads.

---

## Important: stay safe

- **Never use the firmware / version update page** in the app. This project was only
  tested for settings, never for firmware.
- The app runs **offline**, so it can't download firmware or updates by itself.
- Not tested yet: custom/per-key lighting, the color picker, key remapping, macros
  and performance settings. Try them at your own risk.
- If an effect's colors look different after changing it in the app, that's a known
  quirk. Set it back with the keyboard's own Fn shortcuts.

## Problems?

**The app says "no device"**
- Use the USB cable, and set the keyboard to wired mode if it has a mode switch.
- Unplug and replug the keyboard, then fully quit the app (right-click its tray
  icon → Quit) and open it again.
- Make sure you ran Step 4 with `--system` at the end.
- Run `lsusb`. If you don't see `258a:010c`, your keyboard is a different model and
  isn't supported yet.

**The app doesn't open**
- Start it from a terminal so you can see the error: type `aula-hub` and press Enter.
- If it says the offline sandbox isn't allowed: on Ubuntu 24.04+ make sure you used
  `--system`. Otherwise, start it with `AULA_ONLINE=1 aula-hub`, and stay away from
  the firmware page.

**`aula-hub: command not found`**: log out and back in once. The app menu entry
works either way.

**Something else**: open an [issue](https://github.com/Gunerner/aula-hub-linux/issues)
and paste what `aula-hub` prints in a terminal.

## Uninstall

```sh
cd ~/Downloads/aula-hub-linux-main && ./uninstall.sh
```
(Download the project again with Step 3 if you deleted the folder.) It tells you the
command to remove the system settings too.

## For the curious

How it works, what the patches change and the keyboard's settings layout:
[docs/TECHNICAL.md](docs/TECHNICAL.md).

## License

The scripts and patches here are MIT licensed ([LICENSE](LICENSE)). AULA Hub is
proprietary software owned by AULA. It is not included here and not covered by
this license.
