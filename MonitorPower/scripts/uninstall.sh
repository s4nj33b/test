#!/bin/bash
# Removes Monitor Power and restores normal charging.
set -euo pipefail

HELPER=/usr/local/bin/smc-power

pkill -x MonitorPower 2>/dev/null || true
if [[ -x "$HELPER" ]]; then
    sudo "$HELPER" allow || true
fi
sudo rm -f "$HELPER" /etc/sudoers.d/monitor-power
rm -rf /Applications/MonitorPower.app
defaults delete com.s4nj33b.MonitorPower 2>/dev/null || true
echo "Monitor Power removed; charging restored."
