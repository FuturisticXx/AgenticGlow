#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: build-release.sh VERSION}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

Scripts/verify-release-gates.sh
xcodegen generate
rm -rf build/DerivedData build/AgenticGlow.app

xcodebuild build \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$version" \
  CODE_SIGNING_ALLOWED=NO

source_app="build/DerivedData/Build/Products/Release/AgenticGlow.app"
app="build/AgenticGlow.app"
widget="$app/Contents/PlugIns/AgenticGlowWidget.appex"
helper="$app/Contents/Resources/bin/agenticglow-event"
ditto "$source_app" "$app"

codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" "$helper"
codesign --force --options runtime --timestamp \
  --entitlements Config/AgenticGlowWidget.entitlements \
  --sign "$DEVELOPER_ID_APPLICATION" "$widget"
codesign --force --options runtime --timestamp \
  --entitlements Config/AgenticGlow.entitlements \
  --sign "$DEVELOPER_ID_APPLICATION" "$app"

codesign --verify --deep --strict --verbose=2 "$app"
lipo -archs "$app/Contents/MacOS/AgenticGlow"
lipo -archs "$helper"
