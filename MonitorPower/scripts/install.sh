#!/bin/bash
# Builds Monitor Power from source and installs the app plus its root helper.
# Non-technical users can use the DMG from the Releases page instead.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Monitor Power only runs on macOS." >&2
    exit 1
fi
if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user (not with sudo); the script asks for your password when needed." >&2
    exit 1
fi

make app

APP_DST=/Applications/MonitorPower.app

echo "Installing helper and sudoers rule (administrator password required)"
sudo /bin/sh scripts/helper-install.sh install build/smc-power "$(id -un)"

echo "Installing app to $APP_DST"
pkill -x MonitorPower 2>/dev/null || true
rm -rf "$APP_DST"
cp -R build/MonitorPower.app "$APP_DST"

echo "Checking SMC support:"
/usr/local/bin/smc-power status || echo "Warning: this Mac does not expose a supported charge-control SMC key." >&2

open "$APP_DST"
echo "Done. Look for the bolt icon in the menu bar."
