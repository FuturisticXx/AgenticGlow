#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: verify-release.sh VERSION}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

app="build/AgenticGlow.app"
dmg="build/AgenticGlow-${version}.dmg"
helper="$app/Contents/Resources/bin/agenticglow-event"
widget="$app/Contents/PlugIns/AgenticGlowWidget.appex"

test -d "$app"
test -f "$dmg"
test -x "$helper"
test -d "$widget"

[[ "$(lipo -archs "$app/Contents/MacOS/AgenticGlow")" == *arm64* ]]
[[ "$(lipo -archs "$app/Contents/MacOS/AgenticGlow")" == *x86_64* ]]
[[ "$(lipo -archs "$helper")" == *arm64* ]]
[[ "$(lipo -archs "$helper")" == *x86_64* ]]
[[ "$(lipo -archs "$widget/Contents/MacOS/AgenticGlowWidget")" == *arm64* ]]
[[ "$(lipo -archs "$widget/Contents/MacOS/AgenticGlowWidget")" == *x86_64* ]]

codesign --verify --strict --verbose=2 "$widget"
codesign --verify --deep --strict --verbose=2 "$app"
codesign --verify --verbose=2 "$dmg"
widget_entitlements="$(codesign -d --entitlements :- "$widget" 2>/dev/null)"
app_entitlements="$(codesign -d --entitlements :- "$app" 2>/dev/null)"
grep -q '<string>group.com.twodamax.agenticglow</string>' <<< "$widget_entitlements"
grep -q '<string>group.com.twodamax.agenticglow</string>' <<< "$app_entitlements"
spctl --assess --type execute --verbose=2 "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
xcrun stapler validate "$dmg"
Scripts/verify-privacy.sh

mount="$(hdiutil attach -nobrowse -readonly "$dmg" | awk '/\/Volumes\// {print $3; exit}')"
trap 'hdiutil detach "$mount" >/dev/null' EXIT
test -d "$mount/AgenticGlow.app"
test -L "$mount/Applications"
