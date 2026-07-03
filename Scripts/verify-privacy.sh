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

if rg -n 'accessToken|refreshToken|authorizationHeader|OPENAI_API_KEY|ANTHROPIC_API_KEY' \
  Sources/AgenticGlowCore/Allowance Sources/AgenticGlowApp/MenuBar; then
  echo "Forbidden credential material in allowance implementation" >&2
  exit 1
fi

rg -q 'No provider requests are being made' Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift
rg -Fq 'cache.remove(provider)' Sources/AgenticGlowCore/Allowance/AllowanceRefreshCoordinator.swift

for forbidden in prompt assistantMessage command toolInput toolResponse transcriptContents; do
  if rg -q "public let ${forbidden}|public var ${forbidden}" "$schema"; then
    echo "Forbidden stored field: ${forbidden}" >&2
    exit 1
  fi
done
