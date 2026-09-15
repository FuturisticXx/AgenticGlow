#!/usr/bin/env bash
set -euo pipefail

app="${1:-build/AgenticGlow.app}"
executable="$app/Contents/MacOS/AgenticGlow"

test -x "$executable"

"$executable" --remove-integrations &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT

for _ in 1 2 3 4 5; do
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid"
    trap - EXIT
    exit 0
  fi
  sleep 1
done

echo "AgenticGlow --remove-integrations did not exit within 5 seconds" >&2
exit 1
