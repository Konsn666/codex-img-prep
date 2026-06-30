#!/bin/bash
# codex-clip-watch.sh - auto-resize clipboard images for Codex
# Run as a LaunchAgent (every 2s) - when a new image appears on the clipboard,
# if it's > 2MB, shrink it and put the smaller version back.
# Skip if the current image was placed there by us (recursion guard via stamp file).

set -euo pipefail

STAMP=/tmp/.codex-clip-watch.stamp
MAX_BYTES=2097152   # 2MB - resize anything bigger
PREP=/Users/macstudiodisplay/bin/codex-img-prep

# Bail early if no image on clipboard
tmp=$(mktemp -t codex-cw).png
if ! pngpaste "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    exit 0
fi

# shellcheck disable=SC2064  # we want $tmp expanded at signal time
trap 'rm -f "$tmp"' EXIT

# Compare against last-seen hash; skip if unchanged
hash=$(shasum -a 256 "$tmp" | awk '{print $1}')
last_hash=$(cat "$STAMP" 2>/dev/null || echo "")
size=$(stat -f%z "$tmp")

if [[ "$hash" == "$last_hash" ]]; then
    exit 0   # unchanged, nothing to do
fi

if (( size <= MAX_BYTES )); then
    echo "$hash" > "$STAMP"
    exit 0   # already small, just remember it
fi

# Resize via the main script. It modifies in place. Use a temp dir.
work=$(mktemp -d -t codex-cw-work)
cp "$tmp" "$work/in.png"
if "$PREP" "$work/in.png" 2>/dev/null; then
    # Re-encode the resized file as PNG and put on clipboard
    resized_png="$work/in.png"   # script keeps .png extension, writes PNG
    if [[ -f "$resized_png" ]]; then
        # Convert to PNG (already is) and put back on clipboard
        osascript -e "set the clipboard to (POSIX file \"$resized_png\") as «class furl»" >/dev/null 2>&1 || true
        new_hash=$(shasum -a 256 "$resized_png" | awk '{print $1}')
        echo "$new_hash" > "$STAMP"
        # Log
        echo "[$(date '+%H:%M:%S')] 剪贴板已压缩 / resized clipboard ${size}B → $(stat -f%z "$resized_png")B" >> /tmp/codex-clip-watch.log
    fi
fi
rm -rf "$work"