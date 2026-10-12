#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: build-release.sh VERSION}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Config/Version.xcconfig is the one version source. A release whose VERSION
# disagrees with it would ship an Info.plist naming a different version.
configured="$(sed -n 's/^MARKETING_VERSION = //p' Config/Version.xcconfig)"
if [ "$version" != "$configured" ]; then
  echo "error: VERSION $version does not match Config/Version.xcconfig ($configured); update that file first" >&2
  exit 1
fi

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
  CODE_SIGNING_ALLOWED=NO

source_app="build/DerivedData/Build/Products/Release/AgenticGlow.app"
app="build/AgenticGlow.app"
widget="$app/Contents/PlugIns/AgenticGlowWidget.appex"
helper="$app/Contents/Resources/bin/agenticglow-event"
framework="$app/Contents/Frameworks/AgenticGlowCore.framework"
ditto "$source_app" "$app"

# The app's iCloud entitlement is restricted: macOS honors it only when a
# Developer ID provisioning profile that grants it is embedded, and the
# entitlements must name the app and team the profile was issued for. The
# release entitlements are the checked-in file plus exactly what Xcode's
# own Developer ID export adds: the application and team identifiers and
# the Production CloudKit environment. Generated here rather than checked
# in so Debug builds, which Xcode signs for Development, never carry
# Production.
release_entitlements="build/AgenticGlow-release.entitlements"
cp Config/AgenticGlow.entitlements "$release_entitlements"
/usr/libexec/PlistBuddy \
  -c "Add :com.apple.application-identifier string Z52AX2BH7T.com.twodamax.agenticglow" \
  -c "Add :com.apple.developer.team-identifier string Z52AX2BH7T" \
  -c "Add :com.apple.developer.icloud-container-environment string Production" \
  "$release_entitlements"
cp "$DEVELOPER_ID_PROVISIONING_PROFILE" "$app/Contents/embedded.provisionprofile"

# Inside out: the framework and helper first, then the widget, then the
# app whose seal covers them all. An unsigned build leaves the framework
# with only the linker's ad-hoc stub, which a strict deep verify rejects.
codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" "$framework"
codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" "$helper"
codesign --force --options runtime --timestamp \
  --entitlements Config/AgenticGlowWidget.entitlements \
  --sign "$DEVELOPER_ID_APPLICATION" "$widget"
codesign --force --options runtime --timestamp \
  --entitlements "$release_entitlements" \
  --sign "$DEVELOPER_ID_APPLICATION" "$app"

codesign --verify --deep --strict --verbose=2 "$app"
lipo -archs "$app/Contents/MacOS/AgenticGlow"
lipo -archs "$helper"
# Fail closed before anything is notarized or packaged.
Scripts/verify-release-signing.sh "$app"
