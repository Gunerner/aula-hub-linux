#!/bin/bash
# Remove aula-hub-linux. App settings in ~/.config/aula-hub are kept.
set -euo pipefail
DATA_DIR=${AULA_HUB_DIR:-$HOME/.local/share/aula-hub-linux}
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
APPS_DIR=${APPS_DIR:-$HOME/.local/share/applications}

rm -rf "$DATA_DIR"
rm -f "$BIN_DIR/aula-hub" "$APPS_DIR/aula-hub.desktop"
echo "Removed app, launcher and menu entry."
if [ -f /etc/udev/rules.d/70-aula-hub.rules ]; then
    echo "To remove device access too: sudo rm /etc/udev/rules.d/70-aula-hub.rules && sudo udevadm control --reload"
fi
