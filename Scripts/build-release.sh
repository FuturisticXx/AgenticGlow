#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: build-release.sh VERSION}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

Scripts/verify-release-gates.sh
xcodegen generate
rm -rf build/DerivedData build/Klarity.app

xcodebuild build \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$version" \
  CODE_SIGNING_ALLOWED=NO

source_app="build/DerivedData/Build/Products/Release/Klarity.app"
ditto "$source_app" build/Klarity.app

helper="build/Klarity.app/Contents/Resources/bin/klarity-event"
codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" "$helper"
codesign --force --options runtime --timestamp \
  --entitlements Config/Klarity.entitlements \
  --sign "$DEVELOPER_ID_APPLICATION" build/Klarity.app

codesign --verify --deep --strict --verbose=2 build/Klarity.app
lipo -archs build/Klarity.app/Contents/MacOS/Klarity
lipo -archs "$helper"
