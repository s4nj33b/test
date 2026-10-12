#!/bin/bash
# Removes Monitor Power and restores normal charging.
set -euo pipefail

cd "$(dirname "$0")/.."

pkill -x MonitorPower 2>/dev/null || true
sudo /bin/sh scripts/helper-install.sh uninstall
rm -rf /Applications/MonitorPower.app
defaults delete com.s4nj33b.MonitorPower 2>/dev/null || true
echo "Monitor Power removed; charging restored."
