#!/bin/bash
# Install AULA Hub 1.1.22 on Linux from the official Windows installer.
# Usage: ./install.sh "/path/to/Aula Hub Setup 1.1.22.exe" [--system]
#   --system  also set up keyboard access (udev) and, on Ubuntu 24.04+, AppArmor (asks for sudo)
set -euo pipefail

INSTALLER_SHA256=3c03c0a1e53c72ad6ab95e7749dc40f62a6f18e40d7a07d993c5f2bd7d3b77c6
ELECTRON_VERSION=40.10.4   # the version AULA Hub 1.1.22 was built with
ELECTRON_ZIP=electron-v$ELECTRON_VERSION-linux-x64.zip
ELECTRON_SHA256=64b25d8284417fd5c7e2273d7c8f2556f8f98871382e3d0e64f38bf764d0c616
ELECTRON_URL=https://github.com/electron/electron/releases/download/v$ELECTRON_VERSION/$ELECTRON_ZIP

REPO=$(cd "$(dirname "$0")" && pwd)
DATA_DIR=${AULA_HUB_DIR:-$HOME/.local/share/aula-hub-linux}
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
APPS_DIR=${APPS_DIR:-$HOME/.local/share/applications}

die() { echo; echo "ERROR: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

INSTALLER=""
WITH_UDEV=0
for arg in "$@"; do
    case "$arg" in
        --system|--udev) WITH_UDEV=1 ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        *) INSTALLER=$arg ;;
    esac
done
[ -n "$INSTALLER" ] || die "Tell me where the AULA installer is, for example:
  ./install.sh ~/Downloads/\"AULA HUB/Aula Hub Setup 1.1.22.exe\" --system"
[ -f "$INSTALLER" ] || die "File not found: $INSTALLER"

SEVENZIP=$(command -v 7z || command -v 7zz || true)
[ -n "$SEVENZIP" ] || die "7-Zip is missing. Install it first (see README, step 1)."
command -v python3 >/dev/null || die "python3 is missing. Install it first (see README, step 1)."
command -v unshare >/dev/null || die "unshare is missing (package util-linux)."
[ "$(uname -m)" = x86_64 ] || die "Only x86_64 (64-bit Intel/AMD) is supported."

step "Checking the installer"
echo "$INSTALLER_SHA256  $INSTALLER" | sha256sum -c --quiet - >/dev/null 2>&1 \
    || die "This is not the AULA Hub 1.1.22 installer (checksum mismatch). Only 1.1.22 is supported."
echo "OK: AULA Hub 1.1.22"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

step "Unpacking the installer (nothing from it is run)"
"$SEVENZIP" x -tNsis -y -o"$WORK/nsis" "$INSTALLER" >/dev/null
"$SEVENZIP" x -y -o"$WORK/win" "$WORK/nsis/\$PLUGINSDIR/app-64.7z" >/dev/null
python3 -I "$REPO/patches/asar_extract.py" "$WORK/win/resources/app.asar" "$WORK/app"

step "Applying the Linux patches"
python3 -I "$REPO/patches/apply.py" "$WORK/app"

mkdir -p "$DATA_DIR" "$BIN_DIR" "$APPS_DIR"

if command -v electron40 >/dev/null; then
    step "Using your system's Electron 40 ($(command -v electron40))"
elif [ "$(cat "$DATA_DIR/electron/version" 2>/dev/null)" = "$ELECTRON_VERSION" ]; then
    step "Electron $ELECTRON_VERSION already downloaded"
else
    step "Downloading Electron $ELECTRON_VERSION (about 110 MB)"
    command -v curl >/dev/null || die "curl is missing. Install it first (see README, step 1)."
    curl -fL --progress-bar -o "$WORK/$ELECTRON_ZIP" "$ELECTRON_URL" || die "Download failed. Check your internet connection."
    # The expected hash is pinned here, not fetched, so a changed release is rejected.
    echo "$ELECTRON_SHA256  $WORK/$ELECTRON_ZIP" | sha256sum -c --quiet - >/dev/null 2>&1 \
        || die "Electron download doesn't match the expected checksum. Nothing was installed. Try again."
    # Unpack into the temp folder first, so a failure never leaves a half-installed Electron.
    "$SEVENZIP" x -y -o"$WORK/electron" "$WORK/$ELECTRON_ZIP" >/dev/null
    chmod +x "$WORK/electron/electron" "$WORK/electron/chrome_crashpad_handler"
    [ "$(cat "$WORK/electron/version")" = "$ELECTRON_VERSION" ] || die "Unexpected Electron version in the download."
    rm -rf "$DATA_DIR/electron"
    mv "$WORK/electron" "$DATA_DIR/electron"
fi

step "Installing to $DATA_DIR"
rm -rf "$DATA_DIR/app" "$DATA_DIR/icons"
mv "$WORK/app" "$DATA_DIR/app"
cp -r "$WORK/win/resources/build-icons" "$DATA_DIR/icons"

sed "s|@DATA_DIR@|$DATA_DIR|" "$REPO/files/aula-hub" > "$BIN_DIR/aula-hub"
chmod +x "$BIN_DIR/aula-hub"

cat > "$APPS_DIR/aula-hub.desktop" <<EOF
[Desktop Entry]
Name=AULA Hub
Comment=AULA keyboard configuration (unofficial Linux build, offline)
Exec=$BIN_DIR/aula-hub
Icon=$DATA_DIR/icons/logo.png
Terminal=false
Type=Application
Categories=Utility;Settings;HardwareSettings;
EOF

RULE_DEST=/etc/udev/rules.d/70-aula-hub.rules
APPARMOR_DEST=/etc/apparmor.d/aula-hub-linux
# Ubuntu 24.04+ (and Mint, Pop!_OS based on it) block unprivileged user
# namespaces unless an AppArmor profile allows them. Electron's sandbox and
# the offline launcher both need them.
NEEDS_APPARMOR=0
[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = 1 ] && NEEDS_APPARMOR=1

if [ "$WITH_UDEV" = 1 ]; then
    step "Giving your user access to the keyboard (asks for your password)"
    sudo install -m 644 "$REPO/files/70-aula-hub.rules" "$RULE_DEST"
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=hidraw
    if [ "$NEEDS_APPARMOR" = 1 ]; then
        step "Allowing the Electron sandbox and offline mode (AppArmor, Ubuntu 24.04+)"
        sed "s|@ELECTRON@|$DATA_DIR/electron/electron|" "$REPO/files/apparmor-aula-hub-linux" \
            | sudo tee "$APPARMOR_DEST" >/dev/null
        sudo apparmor_parser -r "$APPARMOR_DEST"
    fi
else
    if [ ! -f "$RULE_DEST" ] || { [ "$NEEDS_APPARMOR" = 1 ] && [ ! -f "$APPARMOR_DEST" ]; }; then
        echo
        echo "NOTE: keyboard access is not set up yet. Run the same command again with --system at the end."
    fi
fi

echo
echo "============================================================"
echo " Done! Open \"AULA Hub\" from your app menu, or run: aula-hub"
echo " Never use the firmware / version page."
echo "============================================================"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "(The 'aula-hub' command works after you log out and back in.)";; esac
