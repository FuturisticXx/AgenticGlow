#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$ROOT/Design/AgenticGlowIcon-1024.png"
LIGHT_MASTER="$ROOT/Design/AgenticGlowIcon-Light-1024.png"
ASSETS="$ROOT/Sources/AgenticGlowApp/Resources/Assets.xcassets/AppIcon.appiconset"
EXPECTED_DARK_HASH="58c6c9fbeadd183fac53d8f66155c24994ccb49aed19ae331790517503bd8c0f"
EXPECTED_LIGHT_HASH="3aff401d9475c63b8b20ee37c3291daa608c48e42af13e19cbbbbc26fb8f2dd9"

actual_hash="$(shasum -a 256 "$MASTER" | awk '{print $1}')"
if [[ "$actual_hash" != "$EXPECTED_DARK_HASH" ]]; then
    echo "Approved Glow Mark Dark master hash mismatch." >&2
    exit 1
fi

light_hash="$(shasum -a 256 "$LIGHT_MASTER" | awk '{print $1}')"
if [[ "$light_hash" != "$EXPECTED_LIGHT_HASH" ]]; then
    echo "Approved Glow Mark Light master hash mismatch." >&2
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
