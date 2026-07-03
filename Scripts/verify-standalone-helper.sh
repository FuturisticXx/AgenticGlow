#!/usr/bin/env bash
set -euo pipefail

helper="${1:?usage: verify-standalone-helper.sh HELPER}"
test -x "$helper"

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
cp "$helper" "$temporary/agenticglow-event"

state_directory="$temporary/sessions"
AGENTICGLOW_STATE_DIRECTORY="$state_directory" \
  "$temporary/agenticglow-event" codex Stop --agenticglow-hook <<'JSON'
{"session_id":"standalone-helper","turn_id":"turn","cwd":"/tmp/AgenticGlow"}
JSON

test "$(find "$state_directory" -name '*.json' | wc -l | tr -d ' ')" = "1"
