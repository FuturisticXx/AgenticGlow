#!/usr/bin/env bash
set -euo pipefail

# Pre-build gates for a release candidate. build-release.sh runs this first
# so a candidate is never cut from a tree or a machine that would make the
# real-widget acceptance test meaningless.
#
# - The release inputs are present: signing identity, notary profile, and
#   the Developer ID provisioning profile that carries the iCloud container.
# - The working tree must be clean: the candidate must be reproducible
#   from the commit it claims to come from.
# - Where AgenticGlow is installed, the extension macOS will actually run
#   must be the installed one (verify-widget-registration.sh). A Debug
#   build left registered with LaunchServices or bound inside launchd
#   would make every widget test on this machine test the wrong binary.
#
# Usage: verify-release-gates.sh

required=(
  AGENTICGLOW_NAME_CLEARED
  AGENTICGLOW_RELEASE_BUILD_APPROVED
  DEVELOPER_ID_APPLICATION
  DEVELOPER_ID_PROVISIONING_PROFILE
  NOTARY_PROFILE
)

for variable in "${required[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing release gate: ${variable}" >&2
    exit 1
  fi
done

[[ "$AGENTICGLOW_NAME_CLEARED" == "1" ]]
[[ "$AGENTICGLOW_RELEASE_BUILD_APPROVED" == "1" ]]

# The provisioning profile lives outside the repository (never committed)
# and is handed in by path; the signing verifier checks its contents, this
# only checks it is there before a build spends its time.
if [[ ! -r "$DEVELOPER_ID_PROVISIONING_PROFILE" ]]; then
  echo "DEVELOPER_ID_PROVISIONING_PROFILE is not a readable file: $DEVELOPER_ID_PROVISIONING_PROFILE" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "verify-release-gates: the working tree has uncommitted changes." >&2
  git status --short --untracked-files=no >&2
  exit 1
fi

if [ -d "/Applications/AgenticGlow.app" ]; then
  Scripts/verify-widget-registration.sh
else
  echo "verify-release-gates: AgenticGlow is not installed; skipping the" >&2
  echo "  widget registration gate." >&2
fi

echo "release gates ok"
