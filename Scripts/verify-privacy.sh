#!/usr/bin/env bash
# Scripts/verify-privacy.sh
set -euo pipefail

schema="Sources/AgenticGlowCore/Events/NormalizedEvent.swift"
privacy="docs/privacy.md"

required_fields=(
  schemaVersion provider surface sessionID turnID phase label toolCategory
  projectName workingDirectory sourceBundleID sourceProcessID
  sourceProcessStartedAt turnStartedAt updatedAt
)

for field in "${required_fields[@]}"; do
  rg -q "\\b${field}\\b" "$schema"
  rg -q "\\b${field}\\b" "$privacy"
done

for forbidden in prompt assistantMessage command toolInput toolResponse transcriptContents; do
  if rg -q "public let ${forbidden}|public var ${forbidden}" "$schema"; then
    echo "Forbidden stored field: ${forbidden}" >&2
    exit 1
  fi
done
