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
# The fourth time, pluginkit was correct and launchd was not: chronod's
# per-process domain still held the extension service bound to a Debug
# .appex under DerivedData, so every launch request for the installed
# extension ran that unsigned binary instead ("Attempt to re-bootstrap
# service from different path, will use existing"). It could not read the
# TCC-protected group container, the widget said "Waiting for AgenticGlow"
# over a snapshot the app was writing, and the retries ran at several per
# second. So this script also checks the path launchd will actually execute.
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

# The extension must never execute from a build or staging location, no
# matter which layer names it. Named before the generic mismatch so the
# message says what actually happened.
reject_build_location() {
  case "$1" in
    */DerivedData/*|/tmp/*|/private/tmp/*|*/staging/*|*/Staging/*|*/build/*|*/Build/*)
      echo "verify-widget-registration: $2 resolves the widget extension to" >&2
      echo "  a build or staging location, not the installed app:" >&2
      echo "  $1" >&2
      return 1
      ;;
  esac
}
reject_build_location "$path" "LaunchServices"

# What launchd will run. chronod (WidgetKit's daemon) hosts one launchd
# service per extension it has ever launched this login session, keyed by
# bundle id and bound to the path first used. LaunchServices and pluginkit
# are consulted for the *record*; launchd is what *executes*, and it keeps
# the old path until the domain is torn down.
chronod_pid="$(pgrep -x chronod | head -1 || true)"
if [ -n "$chronod_pid" ]; then
  service="$(launchctl print "pid/$chronod_pid/$widget_id" 2>/dev/null || true)"
  launchd_path="$(printf '%s\n' "$service" | sed -n 's/^[[:space:]]*path = //p' | head -1)"
  if [ -n "$launchd_path" ] && [ "$launchd_path" != "$expected_path" ]; then
    reject_build_location "$launchd_path" "launchd" || {
      echo "This binding cannot be booted out; restart WidgetKit's daemon so" >&2
      echo "it is rebuilt from LaunchServices (widgets reload on their own):" >&2
      echo "  kill $chronod_pid" >&2
      exit 1
    }
    echo "verify-widget-registration: launchd will execute a different" >&2
    echo "  widget extension than the installed one." >&2
    echo "  launchd:  $launchd_path" >&2
    echo "  expected: $expected_path" >&2
    echo "Restart WidgetKit's daemon so the binding is rebuilt from" >&2
    echo "LaunchServices (widgets reload on their own):  kill $chronod_pid" >&2
    exit 1
  fi
fi

# Recent evidence that the wrong binary ran or was refused the container.
# Bounded to a short window so this stays cheap; an empty result is fine.
recent="$(/usr/bin/log show --last 10m --style compact \
  --predicate '(process == "launchd" AND eventMessage CONTAINS "com.twodamax.agenticglow.widget" AND eventMessage CONTAINS "re-bootstrap service from different path") OR (process == "containermanagerd" AND eventMessage CONTAINS "com.twodamax.agenticglow.widget" AND eventMessage CONTAINS "REJECTED")' \
  2>/dev/null | grep -v '^Timestamp' || true)"
if [ -n "$recent" ]; then
  echo "verify-widget-registration: in the last 10 minutes macOS launched or" >&2
  echo "  refused a widget extension other than the installed one:" >&2
  printf '%s\n' "$recent" | tail -5 >&2
  exit 1
fi

echo "widget registration ok: $widget_id $app_version at $path"
