#!/bin/bash
# Install AULA Hub 1.1.22 on Linux from the official Windows installer.
# Usage: ./install.sh "/path/to/Aula Hub Setup 1.1.22.exe" [--udev]
set -euo pipefail

INSTALLER_SHA256=3c03c0a1e53c72ad6ab95e7749dc40f62a6f18e40d7a07d993c5f2bd7d3b77c6
ASAR_PKG=@electron/asar@4.3.1

REPO=$(cd "$(dirname "$0")" && pwd)
DATA_DIR=${AULA_HUB_DIR:-$HOME/.local/share/aula-hub-linux}
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
APPS_DIR=${APPS_DIR:-$HOME/.local/share/applications}

die() { echo "error: $*" >&2; exit 1; }

INSTALLER=""
WITH_UDEV=0
for arg in "$@"; do
    case "$arg" in
        --udev) WITH_UDEV=1 ;;
        -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
        *) INSTALLER=$arg ;;
    esac
done
[ -n "$INSTALLER" ] || die "pass the path to 'Aula Hub Setup 1.1.22.exe' (see README)"
[ -f "$INSTALLER" ] || die "file not found: $INSTALLER"

for cmd in 7z python3 npx electron40 unshare sha256sum; do
    command -v "$cmd" >/dev/null || die "missing dependency: $cmd (see README)"
done

echo "==> Verifying installer checksum"
echo "$INSTALLER_SHA256  $INSTALLER" | sha256sum -c --quiet - \
    || die "checksum mismatch: only AULA Hub 1.1.22 is supported"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "==> Extracting installer (nothing is executed)"
7z x -tNsis -y -o"$WORK/nsis" "$INSTALLER" >/dev/null
7z x -y -o"$WORK/win" "$WORK/nsis/\$PLUGINSDIR/app-64.7z" >/dev/null
npx -y "$ASAR_PKG" extract "$WORK/win/resources/app.asar" "$WORK/app"

echo "==> Applying patches"
python3 -I "$REPO/patches/apply.py" "$WORK/app"

echo "==> Installing to $DATA_DIR"
mkdir -p "$DATA_DIR" "$BIN_DIR" "$APPS_DIR"
rm -rf "$DATA_DIR/app" "$DATA_DIR/icons"
mv "$WORK/app" "$DATA_DIR/app"
cp -r "$WORK/win/resources/build-icons" "$DATA_DIR/icons"

sed "s|\$HOME/.local/share/aula-hub-linux|$DATA_DIR|" "$REPO/files/aula-hub" > "$BIN_DIR/aula-hub"
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
if [ "$WITH_UDEV" = 1 ]; then
    echo "==> Installing udev rule (needs sudo)"
    sudo install -m 644 "$REPO/files/70-aula-hub.rules" "$RULE_DEST"
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=hidraw
elif [ ! -f "$RULE_DEST" ]; then
    echo
    echo "Device access is not set up yet. Run once:"
    echo "  sudo install -m 644 '$REPO/files/70-aula-hub.rules' $RULE_DEST && sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw"
fi

echo
echo "Done. Start it with: aula-hub   (offline; AULA_ONLINE=1 aula-hub to allow network)"
echo "Do NOT use the firmware/version page."
