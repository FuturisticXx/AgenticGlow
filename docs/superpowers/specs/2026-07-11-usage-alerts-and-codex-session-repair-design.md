# Usage Alerts and Codex Session Repair Design

**Date:** 2026-07-11
**Status:** Implemented, verified, and released in v0.4.7 on 2026-07-12

## Goal

Make usage notifications timely and useful without repeating the same warning, and restore live Codex session reporting after the workspace was renamed to AgenticGlow.

## Confirmed Problems

### Repeated Claude usage notifications

AgenticGlow currently deduplicates a low-usage alert using provider, window label, and the provider's reset timestamp. The running app remained alive while repeated 0 percent banners appeared, so the in-memory tracker was not being recreated. A changed reset timestamp therefore produces a new key even though the user is still in one continuous exhausted state.

This conflicts with Apple's guidance to avoid multiple notifications for the same event and to keep notification content concise and useful:

- [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
- [Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications)

### Current Codex session is missing

The active Codex task is still associated with the deleted pre-AgenticGlow path. The renamed checkout exists at:

`/Volumes/Liquid/2DaMax Development/AgenticGlow`

Codex starts the configured hook lifecycle, but a hook command cannot launch from the missing task working directory. No current session event reaches AgenticGlow. The installed AgenticGlow helper successfully writes a valid session event when invoked from the real AgenticGlow directory, so the helper, state store, and resolver are not the cause.

## Notification Design

### State model

Track one alert state for each provider and allowance window:

- `healthy`: 10 percent or more remains.
- `low`: more than 0 percent but less than 10 percent remains.
- `exhausted`: 0 percent remains.

The tracker emits alerts only for meaningful forward transitions:

| Previous observed state | Current observed state | Result |
| --- | --- | --- |
| Unseen or healthy | Low | Send one low-usage alert |
| Unseen, healthy, or low | Exhausted | Send one exhausted alert |
| Low | Low | Stay silent |
| Exhausted | Exhausted | Stay silent |
| Exhausted | Low | Stay silent until healthy recovery |
| Low or exhausted | Healthy | Re-arm the window without an alert |
| Healthy after recovery | Low or exhausted | Start a new alert cycle |

If the first observation is already exhausted, AgenticGlow sends only the exhausted alert. It never sends low and exhausted alerts together.

Reset timestamps do not identify alert cycles. They remain presentation data only. This prevents moving provider timestamps from creating duplicate alerts.

### Notification replacement

Low and exhausted alerts for the same provider and window use the same stable notification identifier. Reaching 0 percent presents a fresh banner and replaces the earlier low warning in Notification Center instead of adding clutter.

The five-hour and weekly windows remain independent. Codex and Claude remain independent.

### Copy

When reset time is known:

- Low title: `Claude usage running low`
- Low body: `5-hour window: 8% left. Resets at 12:50 AM.`
- Exhausted title: `Claude 5-hour usage exhausted`
- Exhausted body: `Available again at 12:50 AM.`

When reset time is unknown:

- Low body: `5-hour window: 8% left.`
- Exhausted body: `No usage remaining in this window.`

Equivalent copy applies to Codex and weekly windows. Titles stay short, direct, and neutral.

### Scope boundaries

- Keep the existing notification preference. Do not add another toggle.
- Do not change the under-10-percent threshold.
- Do not add notification actions or a new settings screen.
- Do not persist raw provider responses or usage history.
- Do not scrape provider or Codex internal databases.
- Do not animate notification-related UI.

## Codex Workspace Repair

Repair the local Codex project association so new AgenticGlow tasks use the existing AgenticGlow directory rather than the retired workspace.

The repair must use Codex's supported project or workspace controls. It must not:

- Recreate the retired workspace as a symlink.
- Patch Codex application binaries.
- Make AgenticGlow depend on Codex's private SQLite or Electron state formats.
- Claim the already-running task is repaired until a real hook event proves it.

Because hook execution belongs to Codex, the currently running task may need to be reopened from the corrected AgenticGlow workspace before it can emit a valid event.

## Components

### `QuotaAlertTracker`

Replace reset-timestamp key accumulation with per-provider, per-window alert state. It accepts normalized allowance snapshots and returns semantic alert events, including whether the event is low or exhausted.

### `AgentNotificationService`

Format the semantic event into user-facing copy. Use the existing stable provider and window notification identifier for both levels so exhaustion replaces the low warning.

Reset-time formatting uses the user's locale and current time zone. Tests use a deterministic locale and time zone.

### Codex integration

No SessionResolver change is planned. Verification must first correct the workspace association, then prove that the existing hook, helper, state store, and resolver pipeline receives a real event.

## Error Handling

- A missing reset time never suppresses an alert. It selects fallback copy.
- Provider percentages remain clamped by `ProviderAllowance`.
- A provider value that moves from exhausted back to low remains silent until a healthy observation re-arms the tracker.
- A failed Codex workspace repair is reported as an external integration blocker. It is not masked with synthetic session data.

## Testing

### Core regression tests

- Healthy to low emits one low alert.
- Repeated low observations stay silent.
- Low to exhausted emits one exhausted alert.
- First observation at 0 percent emits only exhausted.
- Repeated 0 percent observations stay silent.
- Moving reset timestamps do not create new alerts.
- Exhausted to low stays silent.
- Healthy recovery re-arms the next cycle.
- Five-hour and weekly windows are independent.
- Codex and Claude are independent.

### App service tests

- Low copy includes percent left and a known reset time.
- Exhausted copy includes the availability time.
- Unknown reset times use fallback copy.
- Low and exhausted events use the same notification identifier.
- The exhausted title identifies the provider and window.

### Live verification

- Run the focused core and app notification tests.
- Run the broader non-UI test suite and repository verification required for the changed surface.
- Confirm repeated refreshes at 0 percent schedule only one exhausted notification.
- Correct the Codex workspace association.
- Start or reopen a real Codex task from the AgenticGlow directory.
- Confirm a real session file is written with the current Codex process identity.
- Confirm AgenticGlow displays the real Codex session.
- Remove any synthetic diagnostic state used during testing.

## Acceptance Criteria

1. A window warns once below 10 percent and once when it reaches 0 percent.
2. Repeated low or exhausted readings do not create repeated banners.
3. Reset timestamp changes do not bypass deduplication.
4. The 0 percent banner replaces the earlier low notification in Notification Center.
5. Both messages include the reset time when available.
6. Recovery re-arms alerts for a future usage cycle.
7. The Codex workspace points to the real AgenticGlow directory.
8. A real Codex event, not a fixture, appears as a session in AgenticGlow.
