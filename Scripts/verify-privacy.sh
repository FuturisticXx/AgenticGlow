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

# The Messages recipient is personal contact data. It belongs in the Keychain,
# never in a settings plist, and must never reach a log line.
grep -q 'kSecClassGenericPassword' Sources/AgenticGlowApp/Settings/ClaudeSessionCredentialStore.swift
grep -Fq 'SystemKeychainAccess' Sources/AgenticGlowApp/Settings/MessagesRecipientStore.swift
if grep -n 'UserDefaults' Sources/AgenticGlowApp/Settings/MessagesRecipientStore.swift; then
  echo "Messages recipient storage must not use UserDefaults" >&2
  exit 1
fi
# Naming the field is fine; interpolating its value into a log line is not.
if grep -nE 'log\(.*\\\((recipient|alert\.messageText)' \
  Sources/AgenticGlowApp/Services/UsageResetAlertCoordinator.swift; then
  echo "Messages recipient must never be logged" >&2
  exit 1
fi
grep -q 'usage-reset-state.json' "$privacy"
grep -q 'Keychain' "$privacy"

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
