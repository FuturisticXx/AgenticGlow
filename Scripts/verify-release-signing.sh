#!/usr/bin/env bash
set -euo pipefail

# Proves a signed AgenticGlow.app is provisioned the way macOS requires for
# its restricted iCloud entitlement, and that nothing else crept into the
# signature. Runs against the app alone, so build-release.sh can fail
# closed before notarization and verify-release.sh can repeat it on the
# packaged artifact.
#
# Usage: verify-release-signing.sh <AgenticGlow.app>

app="${1:?usage: verify-release-signing.sh APP}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

team="Z52AX2BH7T"
app_id="Z52AX2BH7T.com.twodamax.agenticglow"
app_group="Z52AX2BH7T.group.com.twodamax.agenticglow"
container="iCloud.com.twodamax.agenticglow"
widget="$app/Contents/PlugIns/AgenticGlowWidget.appex"
helper="$app/Contents/Resources/bin/agenticglow-event"
framework="$app/Contents/Frameworks/AgenticGlowCore.framework"
profile="$app/Contents/embedded.provisionprofile"

fail() { echo "verify-release-signing: $*" >&2; exit 1; }
# Several steps below hide a tool's own stderr, so without this an
# unexpected failure under set -e exits 1 with no message at all.
trap 'echo "verify-release-signing: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

test -d "$app" || fail "no app at $app"
test -d "$widget" || fail "no widget at $widget"
test -x "$helper" || fail "no helper at $helper"
test -d "$framework" || fail "no framework at $framework"
test -f "$profile" || fail "no embedded provisioning profile (required for the iCloud entitlement)"

# Read plists with the system's own tools only: nothing here may need Homebrew.
plist_get() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
codesign -d --entitlements "$work/app.plist" --xml "$app" 2>/dev/null
codesign -d --entitlements "$work/widget.plist" --xml "$widget" 2>/dev/null
security cms -D -i "$profile" > "$work/profile.plist"

# --- The app's entitlements are exactly the documented set. ---------------
expected_app_keys="com.apple.application-identifier
com.apple.developer.icloud-container-environment
com.apple.developer.icloud-container-identifiers
com.apple.developer.icloud-services
com.apple.developer.team-identifier
com.apple.security.application-groups
com.apple.security.automation.apple-events"
actual_app_keys="$(/usr/libexec/PlistBuddy -c "Print" "$work/app.plist" | awk '/^    [A-Za-z][^ ]* = / {print $1}' | sort)"
[[ "$actual_app_keys" == "$expected_app_keys" ]] || {
  echo "expected app entitlement keys:" >&2; echo "$expected_app_keys" >&2
  echo "actual app entitlement keys:" >&2; echo "$actual_app_keys" >&2
  fail "unexpected or missing app entitlements"
}
[[ "$(plist_get "$work/app.plist" com.apple.application-identifier)" == "$app_id" ]] || fail "application-identifier is not $app_id"
[[ "$(plist_get "$work/app.plist" com.apple.developer.team-identifier)" == "$team" ]] || fail "team-identifier is not $team"
[[ "$(plist_get "$work/app.plist" com.apple.developer.icloud-container-environment)" == "Production" ]] || fail "iCloud container environment is not Production"
[[ "$(plist_get "$work/app.plist" com.apple.developer.icloud-container-identifiers:0)" == "$container" ]] || fail "iCloud container is not $container"
[[ "$(plist_get "$work/app.plist" com.apple.developer.icloud-services:0)" == "CloudKit" ]] || fail "iCloud service is not CloudKit"
[[ "$(plist_get "$work/app.plist" com.apple.security.application-groups:0)" == "$app_group" ]] || fail "App Group is not $app_group"
# No development-only entitlement, and nothing that would let the app be debugged.
for forbidden in com.apple.security.get-task-allow aps-environment com.apple.developer.ubiquity-kvstore-identifier; do
  if plist_get "$work/app.plist" "$forbidden" >/dev/null; then fail "forbidden entitlement present: $forbidden"; fi
done

# --- The widget's entitlements are exactly sandbox plus the App Group. ----
expected_widget_keys="com.apple.security.app-sandbox
com.apple.security.application-groups"
actual_widget_keys="$(/usr/libexec/PlistBuddy -c "Print" "$work/widget.plist" | awk '/^    [A-Za-z][^ ]* = / {print $1}' | sort)"
[[ "$actual_widget_keys" == "$expected_widget_keys" ]] || fail "unexpected widget entitlements: $actual_widget_keys"
[[ "$(plist_get "$work/widget.plist" com.apple.security.application-groups:0)" == "$app_group" ]] || fail "widget App Group is not $app_group"

# --- The embedded profile is a Developer ID profile for this app that ------
# --- grants everything the app asks for. ----------------------------------
[[ "$(plist_get "$work/profile.plist" TeamIdentifier:0)" == "$team" ]] || fail "profile team is not $team"
[[ "$(plist_get "$work/profile.plist" Platform:0)" == "OSX" ]] || fail "profile platform is not OSX"
[[ "$(plist_get "$work/profile.plist" ProvisionsAllDevices)" == "true" ]] || fail "profile is not a Developer ID (all devices) profile"
[[ "$(plist_get "$work/profile.plist" Entitlements:com.apple.application-identifier)" == "$app_id" ]] || fail "profile application-identifier is not $app_id"
[[ "$(plist_get "$work/profile.plist" Entitlements:com.apple.developer.icloud-container-environment)" == "Production" ]] || fail "profile does not grant the Production CloudKit environment"
profile_containers="$(plist_get "$work/profile.plist" Entitlements:com.apple.developer.icloud-container-identifiers)"
grep -q "$container" <<< "$profile_containers" || fail "profile does not grant $container"
profile_groups="$(plist_get "$work/profile.plist" Entitlements:com.apple.security.application-groups)"
{ grep -q "$app_group" <<< "$profile_groups" || grep -q "$team\.\*" <<< "$profile_groups"; } || fail "profile does not grant $app_group"
expiry="$(plist_get "$work/profile.plist" ExpirationDate)"
expiry_epoch="$(date -j -f "%a %b %d %T %Z %Y" "$expiry" +%s 2>/dev/null || true)"
if [[ -n "$expiry_epoch" ]]; then
  (( expiry_epoch > $(date +%s) + 30*24*3600 )) || fail "profile expires within 30 days: $expiry"
fi
# The profile was issued for a Developer ID Application certificate of this
# team, and that certificate is the one the app is signed with.
codesign -d --extract-certificates="$work/app-cert-" "$app" 2>/dev/null
app_cert_sha1="$(openssl x509 -inform DER -in "$work/app-cert-0" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
cert_count="$(plutil -extract DeveloperCertificates raw -o - "$work/profile.plist")"
matched=""
for ((i = 0; i < cert_count; i++)); do
  plutil -extract "DeveloperCertificates.$i" raw -o - "$work/profile.plist" | base64 --decode > "$work/cert$i.der"
  subject="$(openssl x509 -inform DER -in "$work/cert$i.der" -noout -subject)"
  grep -q "Developer ID Application" <<< "$subject" || fail "profile certificate $i is not a Developer ID Application certificate"
  grep -q "$team" <<< "$subject" || fail "profile certificate $i is not the $team team's"
  sha1="$(openssl x509 -inform DER -in "$work/cert$i.der" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
  [[ "$sha1" == "$app_cert_sha1" ]] && matched="yes"
done
[[ "$matched" == "yes" ]] || fail "the app is signed with a certificate the profile was not issued for"

# --- Signatures: Developer ID, hardened runtime, designated requirement. --
for code in "$app" "$widget" "$helper" "$framework"; do
  info="$(codesign -dvv "$code" 2>&1)"
  grep -q "^Authority=Developer ID Application" <<< "$info" || fail "$code is not signed with Developer ID"
  grep -q "TeamIdentifier=$team" <<< "$info" || fail "$code team identifier is not $team"
  grep -qE "flags=0x[0-9a-f]+\(.*runtime" <<< "$info" || fail "$code lacks the hardened runtime"
  codesign --verify --strict --verbose=2 "$code" 2>&1 | grep -q "satisfies its Designated Requirement" || fail "$code fails its designated requirement"
done
codesign --verify --deep --strict --verbose=2 "$app"

# --- Debug-only verification facilities must be absent. -------------------
Scripts/verify-debug-diagnostics-absent.sh absent "$app"

echo "verify-release-signing: OK ($app)"
