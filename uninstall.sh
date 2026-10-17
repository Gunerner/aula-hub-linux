#!/bin/bash
# Remove aula-hub-linux. App settings in ~/.config/aula-hub are kept.
set -euo pipefail
DATA_DIR=${AULA_HUB_DIR:-$HOME/.local/share/aula-hub-linux}
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
APPS_DIR=${APPS_DIR:-$HOME/.local/share/applications}

rm -rf "$DATA_DIR"
rm -f "$BIN_DIR/aula-hub" "$APPS_DIR/aula-hub.desktop"
echo "Removed the app, launcher and menu entry."

SYSTEM_FILES=()
[ -f /etc/udev/rules.d/70-aula-hub.rules ] && SYSTEM_FILES+=(/etc/udev/rules.d/70-aula-hub.rules)
[ -f /etc/apparmor.d/aula-hub-linux ] && SYSTEM_FILES+=(/etc/apparmor.d/aula-hub-linux)
if [ ${#SYSTEM_FILES[@]} -gt 0 ]; then
    echo "To also remove the system settings, run:"
    [ -f /etc/apparmor.d/aula-hub-linux ] && echo "  sudo apparmor_parser -R /etc/apparmor.d/aula-hub-linux"
    echo "  sudo rm ${SYSTEM_FILES[*]} && sudo udevadm control --reload"
fi
