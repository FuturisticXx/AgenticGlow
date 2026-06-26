# Klarity Task 3 Report

Date: 2026-06-25

## Scope

Implemented Task 3 provider payload normalization for Claude and Codex without allowing raw prompt, command, patch, response, tool input, or notification message content into encoded `NormalizedEvent` output.

## Files changed

- `Klarity.xcodeproj/project.pbxproj`
- `Sources/KlarityCore/Events/HookNormalizer.swift`
- `Sources/KlarityCore/Processes/ProcessIdentity.swift`
- `Tests/KlarityCoreTests/HookNormalizerTests.swift`
- `Tests/Fixtures/claude/user-prompt-submit.json`
- `Tests/Fixtures/claude/permission-request.json`
- `Tests/Fixtures/codex/pre-tool-use.json`
- `Tests/Fixtures/codex/stop.json`

## TDD evidence

### RED

Command:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HookNormalizerTests \
  CODE_SIGNING_ALLOWED=NO
```

Observed failure:

- `Cannot find 'HookNormalizer' in scope`
- `Cannot find 'ProcessIdentity' in scope`
- `Type 'NormalizedEvent' has no member 'testEvent'`

This confirmed the new behavior was not already present.

### GREEN

Implemented the minimal surfaces needed to satisfy the tests:

- `HookNormalizer.normalize(...)`
- `ProcessIdentity`
- `ProcessIdentity.fixture` for tests
- `NormalizedEvent.testEvent(...)` for tests

Focused green command:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HookNormalizerTests \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- `HookNormalizerTests`: 6 tests passed, 0 failures

## Behavior delivered

- Claude `UserPromptSubmit` maps to `.thinking` and starts the turn timer at `now`.
- Claude permission requests map to `.permission` without persisting command payloads.
- Codex `PreToolUse` maps `apply_patch` to `.edit` with label `Editing`.
- Codex `PreToolUse` preserves the previous `turnStartedAt`.
- Codex `Stop` maps to `.completed` and clears `turnStartedAt`.
- Permission-like notifications map to `.permission`.
- Non-permission notifications are ignored.
- Session IDs are sanitized before encoding.
- Normalized output contains only safe metadata fields already defined by `NormalizedEvent`.

## Privacy verification

The new tests explicitly verify encoded `NormalizedEvent` data does not contain:

- `SECRET_PROMPT`
- `SECRET_COMMAND`
- `SECRET_PATCH`
- `SECRET_RESPONSE`
- `SECRET_MESSAGE`
- `tool_input`

## Full verification

Focused suite:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HookNormalizerTests \
  CODE_SIGNING_ALLOWED=NO
```

Result: passed

Full non-UI suite:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -skip-testing:KlarityUITests \
  CODE_SIGNING_ALLOWED=NO
```

Result: passed

Additional check:

```bash
git diff --check
```

Result: clean

## Self-review

- Kept the production change small and limited to the requested Task 3 surface.
- Did not add any new stored content fields to `NormalizedEvent`.
- Used filesystem-backed fixtures with decoy secret strings so the privacy tests stay readable and explicit.
- Added the minimal Xcode project entries required because this project uses explicit file references and source build phase membership.

## Notes

- The broader non-UI test run still logs existing `com.apple.linkd.autoShortcut` connection warnings during app tests, but the suite passes and Task 3 does not depend on or change that area.

---

## Task 3 Fix 1 Report

Date: 2026-06-26

### Scope

Fixed the Task 3 review findings in `HookNormalizer` and `NormalizedEvent` so provider identifiers are privacy-safe, timers are preserved correctly for partial hook streams, non-permission notifications are not over-promoted, and turn IDs are validated with the same safety rules as session IDs.

### RED evidence

Focused command:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HookNormalizerTests \
  CODE_SIGNING_ALLOWED=NO
```

Observed failing regressions before the fix:

- `testClaudePromptHashesRawSessionIdentifierWithoutPersistingIt`
- `testCodexPreToolUseHashesRawTurnIdentifierWithoutPersistingIt`
- `testPreToolUseWithoutPreviousKeepsNilTurnTimer`
- `testPermissionRequestWithoutPreviousKeepsNilTurnTimer`
- `testPermissionNotificationDoesNotPersistMessageContent`
- `testNonPermissionNotificationIsIgnored`
- `testValidationRejectsUnsafeTurnIdentifier`

Failure summaries:

- raw `session_id` still persisted unchanged
- raw `turn_id` still persisted unchanged
- `.preToolUse`, `.permissionRequest`, and permission `.notification` fabricated `turnStartedAt` when `previous` was missing
- `idle_prompt` notification with permission words was incorrectly normalized as `.permission`
- invalid `turnID` values were accepted by `NormalizedEvent.validate()`

### Files changed

- `Sources/KlarityCore/Events/HookNormalizer.swift`
- `Sources/KlarityCore/Events/NormalizedEvent.swift`
- `Tests/KlarityCoreTests/HookNormalizerTests.swift`

### Tests run

Focused:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HookNormalizerTests \
  CODE_SIGNING_ALLOWED=NO
```

Result summary:

- passed
- `HookNormalizerTests`: 12 tests, 0 failures

Full non-UI:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -skip-testing:KlarityUITests \
  CODE_SIGNING_ALLOWED=NO
```

Result summary:

- passed
- suite output in this repo configuration executed 1 non-UI test, 0 failures
- existing `com.apple.linkd.autoShortcut` warnings still appeared during app test startup

### Output summary

- session IDs now store as stable `sid_<sha256-hex>` values
- turn IDs now store as stable `tid_<sha256-hex>` values
- permission fallback now only uses message text when `notification_type` is missing or empty
- `.preToolUse`, `.postToolUse`, `.permissionRequest`, and `.notification` now preserve `previous?.turnStartedAt` exactly
- unknown tools still map to `.other` with label `Using tool`

### Commit SHA

- code fix commit: `241f1a0`

### Concerns

- none
