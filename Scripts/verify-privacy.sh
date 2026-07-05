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
  grep -qw "${field}" "$schema"
  grep -qw "${field}" "$privacy"
done

if grep -rnE 'accessToken|refreshToken|authorizationHeader|OPENAI_API_KEY|ANTHROPIC_API_KEY' \
  Sources/AgenticGlowCore/Allowance Sources/AgenticGlowApp/MenuBar; then
  echo "Forbidden credential material in allowance implementation" >&2
  exit 1
fi

grep -q 'No provider requests are being made' Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift
grep -Fq 'cache.remove(provider)' Sources/AgenticGlowCore/Allowance/AllowanceRefreshCoordinator.swift
grep -q 'kSecClassGenericPassword' Sources/AgenticGlowApp/Settings/ClaudeSessionCredentialStore.swift
grep -q 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' Sources/AgenticGlowApp/Settings/ClaudeSessionCredentialStore.swift
grep -q 'Unofficial Claude connection' Sources/AgenticGlowApp/MenuBar/UsageConsentView.swift

if grep -nE 'sessionCookie|cookie|credential|authorization' \
  Sources/AgenticGlowCore/Allowance/ProviderAllowance.swift \
  Sources/AgenticGlowCore/Allowance/FileAllowanceCache.swift; then
  echo "Credential field found in normalized allowance cache model" >&2
  exit 1
fi

if grep -n 'UserDefaults' Sources/AgenticGlowApp/Settings/ClaudeSessionCredentialStore.swift; then
  echo "Claude credential storage must not use UserDefaults" >&2
  exit 1
fi

for forbidden in prompt assistantMessage command toolInput toolResponse transcriptContents; do
  if grep -qE "public let ${forbidden}|public var ${forbidden}" "$schema"; then
    echo "Forbidden stored field: ${forbidden}" >&2
    exit 1
  fi
done
