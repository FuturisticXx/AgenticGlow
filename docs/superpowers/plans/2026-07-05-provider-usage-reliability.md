# AgenticGlow Provider Usage Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the installed AgenticGlow app reliably display live Codex and Claude subscription allowance for John's real accounts.

**Architecture:** Codex will use the supported local app-server RPC but wait for the initialize response before requesting rate limits. Claude will use an explicitly disclosed private `claude.ai` integration: a user-supplied browser session cookie stored only in macOS Keychain, `lastActiveOrg` extraction from that cookie, and `/api/organizations/{id}/usage` normalization. Existing coordinator, cache, presentation, and opt-in boundaries remain intact.

**Tech Stack:** Swift 6, SwiftUI, Foundation `URLSession`, Security.framework Keychain APIs, XCTest, XcodeGen, macOS 14+

## Global Constraints

- Work only in `/Volumes/Liquid/2DaMax Development/AgenticGlow` on the current `main` checkout.
- Make surgical changes limited to provider allowance reliability.
- Use TDD for every production behavior change and record red then green evidence.
- Never print, persist in UserDefaults, commit, or cache the Claude session cookie.
- Store the Claude cookie in macOS Keychain under AgenticGlow's bundle-owned service.
- Keep usage access off by default and network only after provider-specific opt-in.
- Label Claude usage as an unofficial private integration that may break when Anthropic changes its web API.
- Do not push, publish, tag, or create a release without a separate user request.

---

### Task 1: Repair the Codex app-server handshake

**Files:**
- Modify: `Sources/AgenticGlowCore/Allowance/CodexAllowanceAdapter.swift`
- Modify: `Tests/AgenticGlowCoreTests/CodexAllowanceAdapterTests.swift`

**Interfaces:**
- Produces: `CodexAppServerProtocol.initializeRequest`, `initializedNotification`, and `rateLimitRequest`
- Produces: a `CodexAppServerClient.readRateLimits()` implementation that waits for response ID `1` before sending response ID `7`

- [x] Add a failing process-transport regression test using a deterministic fake app-server executable that rejects an early rate-limit request.
- [x] Run the focused test and confirm it fails because the existing client writes all messages before reading initialization.
- [x] Split the wire messages and make the client read until initialize response ID `1`, then send initialized plus rate-limit read.
- [x] Run `CodexAllowanceAdapterTests` and confirm all tests pass.
- [x] Run a live, credential-safe Codex smoke check and confirm a normalized 5-hour and weekly allowance is returned.

### Task 2: Add Claude usage normalization and HTTP client

**Files:**
- Create: `Sources/AgenticGlowCore/Allowance/ClaudeAllowanceAdapter.swift`
- Create: `Tests/AgenticGlowCoreTests/ClaudeAllowanceAdapterTests.swift`
- Create: `Tests/Fixtures/allowance/claude-usage.json`
- Modify: `Sources/AgenticGlowCore/Allowance/AllowanceAdapter.swift`

**Interfaces:**
- Produces: `ClaudeUsageRequesting.fetchUsage(sessionCookie:) async throws -> Data`
- Produces: `ClaudeAllowanceAdapter` conforming to `AllowanceProviding`
- Normalizes `five_hour.utilization`, `five_hour.resets_at`, `seven_day.utilization`, and `seven_day.resets_at` into `ProviderAllowance`

- [x] Write failing tests for fixture normalization, `lastActiveOrg` extraction, correct endpoint construction, cookie header placement, and 401 handling.
- [x] Run the focused tests and confirm failures are due to missing Claude implementation.
- [x] Implement only the cookie organization extraction and organization-usage request needed by the tests.
- [x] Ensure errors expose actionable states without including response bodies or cookie material.
- [x] Run `ClaudeAllowanceAdapterTests` and confirm all tests pass.

### Task 3: Store the Claude cookie securely and expose explicit setup

**Files:**
- Create: `Sources/AgenticGlowApp/Settings/ClaudeSessionCredentialStore.swift`
- Create: `Tests/AgenticGlowAppTests/ClaudeSessionCredentialStoreTests.swift`
- Modify: `Sources/AgenticGlowApp/MenuBar/UsageConsentView.swift`
- Modify: `Sources/AgenticGlowApp/MenuBar/SessionListView.swift`
- Modify: `Sources/AgenticGlowApp/AppDelegate.swift`
- Modify: `Tests/AgenticGlowAppTests/PreferencesStoreTests.swift`
- Modify: `Tests/AgenticGlowUITests/AgenticGlowUITests.swift`

**Interfaces:**
- Produces: `ClaudeSessionCredentialStoring` with `load()`, `save(_:)`, and `delete()`
- Consumes: `ClaudeAllowanceAdapter` from Task 2

- [x] Write failing tests proving credentials are added, updated, loaded, and deleted through an injectable Keychain client and never written to preferences.
- [x] Write/update UI tests for the unofficial-integration disclosure and cookie entry shown only when Claude is selected.
- [x] Implement the Keychain store using `kSecClassGenericPassword`, service `com.twodamax.agenticglow.claude-session.v1`, and account `claude.ai`.
- [x] Replace the unsupported Claude adapter with a live adapter only when a Keychain credential exists; otherwise report a setup-required state.
- [x] Save or delete the cookie when consent is applied, without logging or copying it into allowance cache data.
- [x] Run focused app and UI tests and confirm they pass.

### Task 4: Update privacy and support documentation

**Files:**
- Modify: `docs/provider-allowance-feasibility.md`
- Modify: `Scripts/verify-privacy.sh`
- Modify: `README.md`

- [x] Document the supported Codex path and the explicitly unsupported/private Claude web path accurately.
- [x] Add privacy checks that reject cookie field names or credential values in normalized allowance and cache models.
- [x] Document how to obtain the Claude session cookie, revoke it, and recover from expiration without claiming Anthropic support.
- [x] Run `Scripts/verify-privacy.sh` and confirm it passes.

### Task 5: Verify, install, and validate the real application

**Files:**
- Modify only if required by a failing acceptance check from this plan.

- [x] Run focused Codex, Claude, Keychain, presentation, and consent tests.
- [x] Run the full AgenticGlow test suite and require zero failures.
- [x] Run `Scripts/verify-privacy.sh`, `Scripts/verify-standalone-helper.sh`, and `git diff --check`.
- [x] Regenerate with `xcodegen generate`, verify deterministic project output, and build Release.
- [x] Install the new build at `/Applications/AgenticGlow.app`, relaunch it, and preserve the user's existing preferences.
- [x] Use the existing ClaudeUsageBar cookie only through local credential migration that never prints it, then remove any migration path after the one-time transfer.
- [x] Trigger live refresh and verify cache files contain normalized Codex and Claude allowance values but no credentials.
- [x] Open the installed menu and visually verify both Codex and Claude rows show real percentages and reset times.
- [x] Re-run the full verification surface after any acceptance-driven fix.

## Acceptance Criteria

- Codex shows real 5-hour and weekly allowance after a sequential app-server handshake.
- Claude shows real 5-hour and weekly allowance from the private web endpoint after explicit consent and Keychain credential setup.
- Neither provider request runs before its provider opt-in.
- The Claude cookie exists only in Keychain and never appears in logs, defaults, normalized cache, fixtures, git diff, or test output.
- Disabling Claude stops requests, clears normalized Claude cache, and deletes the stored cookie.
- `/Applications/AgenticGlow.app` is the rebuilt version and both rows are visually verified against live account data.
- Full tests, privacy checks, helper checks, deterministic generation, Release build, and `git diff --check` pass.
