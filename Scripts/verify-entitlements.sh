#!/usr/bin/env bash
# Scripts/verify-entitlements.sh
set -euo pipefail

app="${1:?usage: verify-entitlements.sh APP_PATH}"
expected_app_group="${2:-Z52AX2BH7T.group.com.twodamax.agenticglow}"

if [[ ! -d "$app" ]]; then
  echo "Error: App bundle not found at $app" >&2
  exit 1
fi

# Extract app entitlements
app_entitlements="$(codesign -d --entitlements :- "$app" 2>/dev/null)"

# Check for unresolved variable syntax
if grep -q '\$(APP_GROUP_ID)' <<< "$app_entitlements"; then
  echo "Error: App contains unresolved APP_GROUP_ID variable in entitlements" >&2
  echo "Found: $(grep -o '\$(APP_GROUP_ID)' <<< "$app_entitlements")" >&2
  exit 1
fi

# Check for empty App Group
if ! grep -q '<string>.*</string>' <<< "$app_entitlements"; then
  echo "Error: App has empty or missing App Group identifier" >&2
  exit 1
fi

# Extract actual App Group identifier
actual_app_group="$(grep -o '<string>[^<]*</string>' <<< "$app_entitlements" | head -1 | sed 's/<string>//;s/<\/string>//')"

# Verify it matches expected
if [[ "$actual_app_group" != "$expected_app_group" ]]; then
  echo "Error: App App Group mismatch" >&2
  echo "Expected: $expected_app_group" >&2
  echo "Actual: $actual_app_group" >&2
  exit 1
fi

# Check widget extension if present
widget="$app/Contents/PlugIns/AgenticGlowWidget.appex"
if [[ -d "$widget" ]]; then
  widget_entitlements="$(codesign -d --entitlements :- "$widget" 2>/dev/null)"

  # Check for unresolved variable syntax
  if grep -q '\$(APP_GROUP_ID)' <<< "$widget_entitlements"; then
    echo "Error: Widget contains unresolved APP_GROUP_ID variable in entitlements" >&2
    exit 1
  fi

  # Extract widget App Group identifier
  actual_widget_group="$(grep -o '<string>[^<]*</string>' <<< "$widget_entitlements" | head -1 | sed 's/<string>//;s/<\/string>//')"

  # Verify widget matches app
  if [[ "$actual_widget_group" != "$actual_app_group" ]]; then
    echo "Error: Widget App Group mismatch with app" >&2
    echo "App: $actual_app_group" >&2
    echo "Widget: $actual_widget_group" >&2
    exit 1
  fi

  # Verify widget matches expected
  if [[ "$actual_widget_group" != "$expected_app_group" ]]; then
    echo "Error: Widget App Group mismatch with expected" >&2
    echo "Expected: $expected_app_group" >&2
    echo "Actual: $actual_widget_group" >&2
    exit 1
  fi
fi

echo "✓ App Group entitlements verified: $actual_app_group"
