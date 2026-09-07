#!/usr/bin/env bash
# Scripts/verify-privacy.sh
set -euo pipefail

schema="Sources/AgenticGlowCore/Events/NormalizedEvent.swift"
privacy="docs/privacy.md"

required_fields=(
  schemaVersion provider surface sessionID turnID phase label toolCategory
  projectName workingDirectory sourceBundleID sourceProcessID
  sourceProcessStartedAt turnStartedAt updatedAt model
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

grep -q 'No usage requests are being made' Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift
grep -Fq 'cache.remove(provider)' Sources/AgenticGlowCore/Allowance/AllowanceRefreshCoordinator.swift
credential_store="Sources/AgenticGlowApp/Settings/SessionCredentialStore.swift"
grep -q 'kSecClassGenericPassword' "$credential_store"
grep -q 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' "$credential_store"
grep -q 'Unofficial provider connections' Sources/AgenticGlowApp/MenuBar/UsageConsentView.swift

# Each provider's credential lives under its own Keychain service, so one
# provider's Usage Access can never read or delete another's.
grep -q 'com.twodamax.agenticglow.claude-session.v1' "$credential_store"
grep -q 'com.twodamax.agenticglow.cursor-session.v1' "$credential_store"

# Cursor allowance must stay a user-pasted credential. AgenticGlow must never
# read Cursor's own session storage or any browser cookie database.
#
# Defense in depth, not the boundary itself. The boundary is structural: the
# Cursor adapter receives its cookie through an injected closure and has no
# storage access of its own, so there is no code path from the adapter to any
# credential store other than the app's own Keychain entry. These greps only
# catch a future edit that reaches for the well-known extraction sources.
if grep -rniE 'state\.vscdb|cursorAuth|WorkosCursorSessionToken|Cookies\.binarycookies|cookies\.sqlite' \
  Sources/AgenticGlowCore Sources/AgenticGlowApp; then
  echo "Cursor credential extraction path found; the cookie must be user-supplied" >&2
  exit 1
fi

# The structural half of the same guarantee: the Cursor adapter reads no
# storage, so it cannot acquire a credential on its own.
cursor_adapter="Sources/AgenticGlowCore/Allowance/CursorAllowanceAdapter.swift"
if grep -nE '^import (Security|SQLite3)|FileManager|SecItem' "$cursor_adapter"; then
  echo "Cursor adapter must not read local storage; its cookie is injected" >&2
  exit 1
fi

if grep -nE 'sessionCookie|cookie|credential|authorization' \
  Sources/AgenticGlowCore/Allowance/ProviderAllowance.swift \
  Sources/AgenticGlowCore/Allowance/AllowancePool.swift \
  Sources/AgenticGlowCore/Allowance/FileAllowanceCache.swift; then
  echo "Credential field found in normalized allowance cache model" >&2
  exit 1
fi

if grep -n 'UserDefaults' "$credential_store"; then
  echo "Session credential storage must not use UserDefaults" >&2
  exit 1
fi

# Provider status checks must stay credential-free and fully documented.
grep -q 'status.claude.com' Sources/AgenticGlowCore/Status/StatusPageClient.swift
grep -q 'status.openai.com' Sources/AgenticGlowCore/Status/StatusPageClient.swift
grep -q 'status.cursor.com' Sources/AgenticGlowCore/Status/StatusPageClient.swift
grep -q 'status.claude.com' "$privacy"
grep -q 'status.openai.com' "$privacy"
grep -q 'status.cursor.com' "$privacy"
if grep -rniE 'cookie|credential|authorization' Sources/AgenticGlowCore/Status; then
  echo "Forbidden credential material in provider status implementation" >&2
  exit 1
fi

for forbidden in prompt assistantMessage command toolInput toolResponse transcriptContents; do
  if grep -qE "public let ${forbidden}|public var ${forbidden}" "$schema"; then
    echo "Forbidden stored field: ${forbidden}" >&2
    exit 1
  fi
done
