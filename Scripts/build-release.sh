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
ditto "$source_app" build/AgenticGlow.app

helper="build/AgenticGlow.app/Contents/Resources/bin/agenticglow-event"
codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" "$helper"
codesign --force --options runtime --timestamp \
  --entitlements Config/AgenticGlow.entitlements \
  --sign "$DEVELOPER_ID_APPLICATION" build/AgenticGlow.app

codesign --verify --deep --strict --verbose=2 build/AgenticGlow.app
lipo -archs build/AgenticGlow.app/Contents/MacOS/AgenticGlow
lipo -archs "$helper"
