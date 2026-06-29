#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: verify-release.sh VERSION}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

app="build/Klarity.app"
dmg="build/Klarity-${version}.dmg"
helper="$app/Contents/Resources/bin/klarity-event"

test -d "$app"
test -f "$dmg"
test -x "$helper"

[[ "$(lipo -archs "$app/Contents/MacOS/Klarity")" == *arm64* ]]
[[ "$(lipo -archs "$app/Contents/MacOS/Klarity")" == *x86_64* ]]
[[ "$(lipo -archs "$helper")" == *arm64* ]]
[[ "$(lipo -archs "$helper")" == *x86_64* ]]

codesign --verify --deep --strict --verbose=2 "$app"
codesign --verify --verbose=2 "$dmg"
spctl --assess --type execute --verbose=2 "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
xcrun stapler validate "$dmg"
Scripts/verify-privacy.sh

mount="$(hdiutil attach -nobrowse -readonly "$dmg" | awk '/\/Volumes\// {print $3; exit}')"
trap 'hdiutil detach "$mount" >/dev/null' EXIT
test -d "$mount/Klarity.app"
test -L "$mount/Applications"
