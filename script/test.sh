#!/usr/bin/env bash
set -euo pipefail

# Runs the unit test suites.
#
# The app suite is hosted in the app and runs under xcodebuild. UI tests need
# the real signing identity and are opt-in: passing CODE_SIGNING_ALLOWED=NO
# strips the app's automation identity and the runner hangs before it connects.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

derived="${AGENTICGLOW_DERIVED_DATA:-$HOME/Library/Developer/AgenticGlow/DerivedData}"
products="$derived/Build/Products/Debug"

mkdir -p "$derived"

xcodebuild build-for-testing \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -configuration Debug \
  -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO

for bundle in AgenticGlowCoreTests AgenticGlowEventTests AgenticGlowWidgetTests; do
  echo "== $bundle"
  xcrun xctest "$products/$bundle.xctest"
done

echo "== AgenticGlowAppTests"
xcodebuild test-without-building \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -configuration Debug \
  -derivedDataPath "$derived" \
  -only-testing:AgenticGlowAppTests \
  CODE_SIGNING_ALLOWED=NO

if [ "${1:-}" = "--ui" ]; then
  echo "== AgenticGlowUITests (real signing identity)"
  xcodebuild test \
    -project AgenticGlow.xcodeproj \
    -scheme AgenticGlow \
    -configuration Debug \
    -derivedDataPath "$derived-ui" \
    -only-testing:AgenticGlowUITests
fi
