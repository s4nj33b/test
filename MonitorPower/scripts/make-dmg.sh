#!/bin/bash
# Packages an app bundle into a compressed, drag-to-Applications DMG.
#
#   make-dmg.sh <path/to/App.app> <output.dmg> <volume name>
#
# `hdiutil create -srcfolder` regularly fails with "Resource busy" when a
# volume with the same name is still mounted, or when Spotlight or endpoint
# security software is scanning the freshly built files. This script detaches
# stale volumes, retries, and finally falls back to building the image by hand
# (blank image -> attach -> copy -> detach -> compress), which avoids it.
set -euo pipefail

APP=$1
OUT=$2
VOLNAME=$3

WORK="$(dirname "$OUT")/dmg-work"
STAGE="$WORK/stage"
MOUNT="$WORK/mount"

cleanup() {
    hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

detach_stale_volumes() {
    local vol
    for vol in "/Volumes/$VOLNAME" "/Volumes/$VOLNAME "[0-9]*; do
        if [[ -d "$vol" ]]; then
            echo "Ejecting previously mounted \"$vol\""
            hdiutil detach "$vol" -force >/dev/null 2>&1 || true
        fi
    done
}

rm -rf "$WORK" "$OUT"
mkdir -p "$STAGE" "$MOUNT"
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"
# Keep Spotlight from indexing the staging folder while hdiutil reads it.
touch "$STAGE/.metadata_never_index"

detach_stale_volumes

# 1) Normal path, with a few retries. MAKE_DMG_FALLBACK=1 skips it (for testing).
for attempt in 1 2 3; do
    [[ "${MAKE_DMG_FALLBACK:-0}" == 1 ]] && break
    if hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUT"; then
        echo "Created $OUT"
        exit 0
    fi
    echo "hdiutil create failed (attempt $attempt/3); retrying in $((attempt * 3)) s" >&2
    sleep $((attempt * 3))
    detach_stale_volumes
done

# 2) Fallback: build a writable image by hand, then compress it.
echo "Falling back to manual image build" >&2
RW="$WORK/rw.dmg"
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 20 ))
hdiutil create -size "${SIZE_MB}m" -fs HFS+ -volname "$VOLNAME" -type UDIF -ov "$RW"
hdiutil attach "$RW" -nobrowse -noautoopen -mountpoint "$MOUNT"
ditto "$STAGE" "$MOUNT"
rm -f "$MOUNT/.metadata_never_index"
sync
for attempt in 1 2 3 4 5; do
    hdiutil detach "$MOUNT" >/dev/null 2>&1 && break
    sleep 2
    [[ $attempt -eq 5 ]] && hdiutil detach "$MOUNT" -force
done
hdiutil convert "$RW" -format UDZO -o "$OUT" -ov
echo "Created $OUT"
