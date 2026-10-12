#!/bin/bash
# Builds MonitorPower-<version>.dmg on a Mac.
#
#   ./scripts/build-dmg.sh            # version from App/Info.plist
#   ./scripts/build-dmg.sh 0.02       # custom version
#
# Optional notarized build (needs an Apple Developer account, see README):
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   APPLE_ID=... APPLE_TEAM_ID=... APPLE_APP_PASSWORD=... ./scripts/build-dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "DMG builds need macOS." >&2
    exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools are missing. Installing; re-run this script when done." >&2
    xcode-select --install || true
    exit 1
fi

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' App/Info.plist)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
DMG="build/MonitorPower-$VERSION.dmg"

echo "==> Building Monitor Power $VERSION"
make clean
make dmg VERSION="$VERSION" SIGN_IDENTITY="$SIGN_IDENTITY"

if [[ "$SIGN_IDENTITY" != "-" && -n "${APPLE_ID:-}" ]]; then
    echo "==> Notarizing (this can take a few minutes)"
    make notarize VERSION="$VERSION" SIGN_IDENTITY="$SIGN_IDENTITY"
fi

echo "==> Verifying"
codesign --verify --deep --strict build/MonitorPower.app
hdiutil verify "$DMG" >/dev/null

echo
echo "Done: $(pwd)/$DMG ($(du -h "$DMG" | cut -f1))"
open -R "$DMG"
