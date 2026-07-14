# Client-Side Session Removal Design

Date: 2026-07-13
Status: Approved by John

## Problem

`SessionResolver` now expires `thinking`/`usingTool` sessions after 30 minutes
of inactivity (v0.4.10), but `permission` never auto-expires — an abandoned
approval prompt sits in the popover indefinitely. `completed`, `idle`, and
`disconnected` rows can also linger for up to 24 hours (`fileRetention`)
before the underlying file ages out. John wants a way to manually clear a
stale-looking row without waiting.

## Approved behavior

**Scope.** "Remove" is available only on `.idle`, `.disconnected`,
`.completed`, and `.permission` rows. `.thinking` and `.usingTool` rows get no
context menu at all — they already self-heal via the staleness timeout, and
hiding a genuinely active session would just flicker back on its next event
(worse UX than not offering it).

**Mechanism.** Fully client-side. Removing a session never touches
`SessionStateStore` or the on-disk JSON file — it records a hide in
`ResolutionMemory`, keyed by `SessionKey` plus the `eventUpdatedAt` that was
current at the moment of hiding. `SessionResolver.resolve()` excludes a
session whose event still matches its hidden record. If a *newer* event
arrives for that key (the file was rewritten with new data), the record no
longer matches, the hide is cleared, and the session reappears as a normal
row — no special "reappeared" treatment, exactly like every other state
transition in this app is silent.

Because it's memory-only, a hide does not survive an AgenticGlow relaunch,
and it doesn't persist to disk in any form.

**Interaction.** Right-click (macOS context menu) on a removable row shows a
single "Remove" item with a destructive (red) tint and an `xmark.circle`
icon. No confirmation dialog — this is a non-destructive dismiss, not a
delete: worst case, a still-live session simply reappears on its next event.

## Architecture

- `ResolutionMemory` (AgenticGlowCore) gains `hiddenRecords:
  [SessionKey: HiddenRecord]`, parallel to the existing `disconnectedRecords`.
  `HiddenRecord` stores only `eventUpdatedAt`.
- `ResolutionMemory` exposes `public mutating func hide(_ key: SessionKey,
  eventUpdatedAt: Date)` so `AppModel`, in a different module, can record a
  hide without reaching into resolver internals.
- `SessionResolver.resolve()`: at the top, prune `hiddenRecords` to keys still
  present in `retainedKeys` (same pattern as the existing
  `disconnectedRecords` pruning). Per event, after the `fileRetention` check
  and before phase resolution, check `hiddenRecords[key]`: if its
  `eventUpdatedAt` equals the event's `updatedAt`, return `nil` (exclude from
  snapshots). If a record exists but doesn't match, clear it and proceed
  normally.
- `AppModel.removeSession(_ session: SessionSnapshot)`: calls
  `resolutionMemory.hide(SessionKey(provider:sessionID:), eventUpdatedAt:
  session.updatedAt)`, then calls `refresh()` immediately so the row
  disappears without waiting for the next 2-second timer tick.
- `SessionRowView`: new `onRemove: () -> Void` param, computed `isRemovable`
  (true for `.idle`, `.disconnected`, `.completed`, `.permission`). When
  removable, the row attaches `.contextMenu { Button("Remove",
  systemImage: "xmark.circle", role: .destructive, action: onRemove) }`; when
  not, no context menu is attached at all.
- `SessionListView`: passes `onRemove: { model.removeSession(session) }`
  through to each row.

## Edge cases

- A hidden `.permission` session gets approved/denied elsewhere and the
  provider sends a new hook event: the hide is cleared by the newer
  `updatedAt`, and the row reappears in whatever new phase it's now in.
- A hidden session's file ages past `fileRetention` (24h) with no new
  activity: pruning removes the now-orphaned `hiddenRecords` entry, so memory
  doesn't grow unbounded across long-running AgenticGlow sessions.
- Two rapid hides of the same key in one popover interaction: the second call
  just overwrites the `HiddenRecord` with the same `eventUpdatedAt` — no-op.
- AgenticGlow relaunches: all hides are forgotten, matching the "client-side
  only" requirement. A genuinely dead session will reappear until it
  naturally expires again.

## Verification

- `SessionResolverTests`: hidden session excluded from `resolved.sessions`;
  hidden session reappears when a newer event supersedes it; hidden record is
  pruned once its key falls out of retention.
- `AppModelTests`: `removeSession(_:)` hides the correct key and the session
  is absent from `resolved.sessions` on the next `refresh()`.
- No new view-level unit test (matches existing convention — row
  icon/color logic isn't unit-tested directly either). Manual verification:
  build, launch, right-click a `.permission` row and confirm a "Remove" item
  appears and clears it; right-click a `.thinking`/`.usingTool` row and
  confirm no context menu appears at all.
