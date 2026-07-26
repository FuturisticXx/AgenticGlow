#!/usr/bin/env bash
set -euo pipefail

# Asserts that the widget extension macOS will actually run is the installed
# one. A shared snapshot, a valid signature, and a registered extension are
# each insufficient evidence on their own (docs/release-checklist.md); this
# covers the specific failure where something else holds the registration.
#
# Worth running after any local build, not just at release: Xcode's
# RegisterWithLaunchServices build phase runs on every build, so a Debug
# build can silently become the only registered extension and serve stale
# code to the desktop indefinitely. That has happened three times in this
# project's history.
#
# Usage: verify-widget-registration.sh [EXPECTED_VERSION]

expected_version="${1:-}"
app="/Applications/AgenticGlow.app"
widget_id="com.twodamax.agenticglow.widget"
expected_path="$app/Contents/PlugIns/AgenticGlowWidget.appex"

test -d "$app"
test -d "$expected_path"

listing="$(pluginkit -m -A -D -v -i "$widget_id" 2>/dev/null || true)"
entries="$(printf '%s\n' "$listing" | grep -F "$widget_id(" || true)"
count="$(printf '%s\n' "$entries" | grep -c . || true)"

if [ "$count" != "1" ]; then
  echo "verify-widget-registration: expected exactly 1 registration for" >&2
  echo "  $widget_id, found $count." >&2
  echo "Registrations:" >&2
  printf '%s\n' "$listing" >&2
  echo "Remove the unwanted ones with: pluginkit -r <path>" >&2
  exit 1
fi

path="$(printf '%s\n' "$entries" | awk -F'\t' '{print $NF}')"
if [ "$path" != "$expected_path" ]; then
  echo "verify-widget-registration: the registered extension is not the" >&2
  echo "  installed one." >&2
  echo "  registered: $path" >&2
  echo "  expected:   $expected_path" >&2
  echo "Fix with: pluginkit -r \"$path\" && pluginkit -a \"$expected_path\"" >&2
  exit 1
fi

registered_version="$(printf '%s\n' "$entries" \
  | sed -n "s/.*${widget_id}(\([^)]*\)).*/\1/p")"
app_version="$(defaults read "$app/Contents/Info.plist" CFBundleShortVersionString)"

if [ "$registered_version" != "$app_version" ]; then
  echo "verify-widget-registration: the registration is stale." >&2
  echo "  registered version: $registered_version" >&2
  echo "  installed app:      $app_version" >&2
  echo "Re-register with: pluginkit -a \"$expected_path\"" >&2
  exit 1
fi

if [ -n "$expected_version" ] && [ "$app_version" != "$expected_version" ]; then
  echo "verify-widget-registration: installed version $app_version does not" >&2
  echo "  match the expected $expected_version." >&2
  exit 1
fi

echo "widget registration ok: $widget_id $app_version at $path"
