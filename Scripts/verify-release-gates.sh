#!/usr/bin/env bash
# Scripts/verify-release-gates.sh
set -euo pipefail

required=(
  AGENTICGLOW_NAME_CLEARED
  AGENTICGLOW_RELEASE_BUILD_APPROVED
  DEVELOPER_ID_APPLICATION
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
