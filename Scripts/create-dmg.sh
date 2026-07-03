#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: create-dmg.sh VERSION}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

Scripts/verify-release-gates.sh
app="build/AgenticGlow.app"
dmg="build/AgenticGlow-${version}.dmg"
stage="build/dmg-stage"
test -d "$app"
rm -rf "$stage" "$dmg"
mkdir -p "$stage"
ditto "$app" "$stage/AgenticGlow.app"
ln -s /Applications "$stage/Applications"

hdiutil create \
  -volname "AgenticGlow" \
  -srcfolder "$stage" \
  -ov \
  -format UDZO \
  "$dmg"

codesign --force --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" "$dmg"
xcrun notarytool submit "$dmg" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
rm -rf "$stage"
