#!/bin/bash
# Installs the smc-power helper (root-owned), a sudoers rule that lets the
# current user run only that helper without a password, and the menu bar app.
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

make all

HELPER_DST=/usr/local/bin/smc-power
SUDOERS_DST=/etc/sudoers.d/monitor-power
APP_DST=/Applications/MonitorPower.app
USER_NAME="$(id -un)"

echo "Installing helper to $HELPER_DST"
sudo mkdir -p /usr/local/bin
sudo install -o root -g wheel -m 755 build/smc-power "$HELPER_DST"

echo "Installing sudoers rule to $SUDOERS_DST"
TMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TMP_SUDOERS"' EXIT
cat > "$TMP_SUDOERS" <<RULE
# Allows Monitor Power to toggle MacBook charging without a password prompt.
$USER_NAME ALL=(root) NOPASSWD: $HELPER_DST allow, $HELPER_DST inhibit, $HELPER_DST block, $HELPER_DST status
RULE
sudo visudo -cf "$TMP_SUDOERS"
sudo install -o root -g wheel -m 440 "$TMP_SUDOERS" "$SUDOERS_DST"

echo "Installing app to $APP_DST"
pkill -x MonitorPower 2>/dev/null || true
rm -rf "$APP_DST"
cp -R build/MonitorPower.app "$APP_DST"

echo "Checking SMC support:"
"$HELPER_DST" status || echo "Warning: this Mac does not expose a supported charge-control SMC key." >&2

open "$APP_DST"
echo "Done. Look for the bolt icon in the menu bar."
