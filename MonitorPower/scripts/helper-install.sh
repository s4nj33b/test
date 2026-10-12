#!/bin/sh
# Installs or removes the smc-power helper and its sudoers rule. Must run as root.
#
#   helper-install.sh install <path-to-smc-power> <user-name>
#   helper-install.sh uninstall
#
# Used by both scripts/install.sh and the app's first-launch setup, which runs
# it from inside the signed app bundle via an administrator-privileges prompt.
set -eu

HELPER=/usr/local/bin/smc-power
SUDOERS=/etc/sudoers.d/monitor-power

if [ "$(id -u)" -ne 0 ]; then
    echo "helper-install.sh must run as root" >&2
    exit 1
fi

case "${1:-}" in
install)
    src=${2:?missing helper path}
    user=${3:?missing user name}
    case "$user" in
        *[!A-Za-z0-9._-]*) echo "invalid user name: $user" >&2; exit 1 ;;
    esac

    mkdir -p /usr/local/bin
    install -o root -g wheel -m 755 "$src" "$HELPER"

    tmp=$(mktemp /tmp/monitor-power.XXXXXX)
    trap 'rm -f "$tmp"' EXIT
    cat > "$tmp" <<RULE
# Allows Monitor Power to toggle MacBook charging without a password prompt.
$user ALL=(root) NOPASSWD: $HELPER allow, $HELPER inhibit, $HELPER block, $HELPER status
RULE
    visudo -cf "$tmp" >/dev/null
    install -o root -g wheel -m 440 "$tmp" "$SUDOERS"
    ;;
uninstall)
    if [ -x "$HELPER" ]; then
        "$HELPER" allow || true
    fi
    rm -f "$HELPER" "$SUDOERS"
    ;;
*)
    echo "usage: $0 install <helper> <user> | uninstall" >&2
    exit 2
    ;;
esac
