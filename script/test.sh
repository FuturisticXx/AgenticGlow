#!/usr/bin/env bash
set -euo pipefail

# Runs the unit suites from a working copy on the exFAT volume.
#
# Two things break a plain `xcodebuild test` here, both environmental:
#
#   1. Build products cannot live on exFAT. The test bundle builds correctly
#      but the runner cannot load it: "the bundle's executable couldn't be
#      located", with the executable present and correctly named. So the
#      derived data goes on the internal disk.
#   2. xcodebuild's test runner has no access to this removable volume, so a
#      test reading a fixture or a script out of the source tree through
#      #filePath fails with "Operation not permitted". Launching the bundle
#      directly with xctest keeps this shell's access, so those tests pass.
#
# The app suite is hosted in the app and unaffected by either, so it stays on
# xcodebuild. UI tests need the real signing identity and are opt-in: passing
# CODE_SIGNING_ALLOWED=NO strips the app's automation identity and the runner
# hangs before it connects (tasks/lessons.md, 2026-07-10).

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

derived="${AGENTICGLOW_DERIVED_DATA:-$HOME/Library/Developer/AgenticGlow/DerivedData}"
case "$derived" in
  /Volumes/*)
    echo "error: derived data must not live on the exFAT volume: $derived" >&2
    exit 2
    ;;
esac
products="$derived/Build/Products/Debug"

mkdir -p "$derived"

xcodebuild build-for-testing \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -configuration Debug \
  -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO

for bundle in AgenticGlowCoreTests AgenticGlowEventTests; do
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
