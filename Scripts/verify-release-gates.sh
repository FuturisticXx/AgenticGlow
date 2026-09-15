#!/usr/bin/env bash
set -euo pipefail

# Pre-build gates for a release candidate. build-release.sh runs this first
# so a candidate is never cut from a tree or a machine that would make the
# real-widget acceptance test meaningless.
#
# - The working tree must be clean: the candidate must be reproducible
#   from the commit it claims to come from.
# - Where AgenticGlow is installed, the extension macOS will actually run
#   must be the installed one (verify-widget-registration.sh). A Debug
#   build left registered with LaunchServices or bound inside launchd
#   would make every widget test on this machine test the wrong binary.
#
# Usage: verify-release-gates.sh

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
