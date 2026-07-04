#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$ROOT/Design/AgenticGlowIcon-1024.png"
ASSETS="$ROOT/Sources/AgenticGlowApp/Resources/Assets.xcassets/AppIcon.appiconset"
REJECTED_HASH="f3d4900ce6aa4d8b7444ca3e4407ad0371ac42e6643e6731299503922247c111"

actual_hash="$(shasum -a 256 "$MASTER" | awk '{print $1}')"
if [[ "$actual_hash" == "$REJECTED_HASH" ]]; then
    echo "Rejected AgenticGlow icon is still installed." >&2
    exit 1
fi

cmp "$MASTER" "$ASSETS/icon_512x512@2x.png"

while read -r file expected; do
    width="$(sips -g pixelWidth "$ASSETS/$file" | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "$ASSETS/$file" | awk '/pixelHeight/ {print $2}')"
    if [[ "$width" != "$expected" || "$height" != "$expected" ]]; then
        echo "$file is ${width}x${height}; expected ${expected}x${expected}." >&2
        exit 1
    fi
done <<'SIZES'
icon_16x16.png 16
icon_16x16@2x.png 32
icon_32x32.png 32
icon_32x32@2x.png 64
icon_128x128.png 128
icon_128x128@2x.png 256
icon_256x256.png 256
icon_256x256@2x.png 512
icon_512x512.png 512
icon_512x512@2x.png 1024
SIZES

echo "AgenticGlow app icon assets verified."
