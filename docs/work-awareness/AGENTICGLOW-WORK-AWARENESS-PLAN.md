# AgenticGlow Work Awareness Plan

Date: 2026-08-21
Status: implementation-ready design. No code was changed.
Milestone: prove the revised thesis, **Work is the object. Attention is the sort key**, without bloating AgenticGlow or redesigning the widget.

This document is the decision gate for Phase 1. It is not an implementation.

Evidence labels: **Observed**, **Documented**, **Inferred**, **Proposed**.

---

## 1. Executive Summary

Work Awareness can ship as a **data and grouping change** that the existing widget and popover already know how to show.

The current widget already treats `projectName` as the primary row title. Tonight that name is only the folder basename, and four Cursor sessions in the same folder still occupy four rows. **Observed.** The first milestone should:

1. Stop dropping `workingDirectory` before the UI.
2. Group sessions by a normalized directory identity.
3. Compress a shared-work group into **one existing session row**.
4. Leave every other widget surface alone.

When only one session is attached to a piece of work, the widget should be visually identical to today. The new intelligence should appear only when two or more sessions share a folder, or when something actually needs the user.

**Proposed identity:** Option A, exact normalized working directory. Not git root. Not a project database. Not branch awareness.

**Proposed recommendation:** READY TO IMPLEMENT.

---

## 2. Current Widget Baseline

Protect this. It is the visual contract.

### Surfaces

| Family | Job today | Density |
| --- | --- | --- |
| Small | One headline: attention count, else active count, else lowest allowance, else "All quiet" | One number, one subtitle |
| Medium | Up to 2 session rows + one lowest-window allowance bar | Short, no banner |
| Large | 2-4 session rows + per-provider allowance strips | Fixed canvas, overflow drops off the bottom |

**Documented** in `docs/widget.md` and **Observed** in `SmallWidgetView`, `MediumWidgetView`, `LargeWidgetView`.

### Session row geometry (medium compact, large detailed)

```text
[phase icon 18pt]  projectName 14pt semibold
                   phase label 12pt secondary   [elapsed 12pt]
```

Large appends ` · {provider}` to the phase label. The whole row is already a `Link` to `agenticglow://session?...`. There is no Open button, no attention banner, no work header, no model slug.

**Observed** in `Sources/AgenticGlowWidget/Views/SessionRow.swift`.

### What the widget deliberately does not do

- No attention banner on medium or large. Prompting belongs to the menu bar and notifications. **Documented.**
- No interactive App Intents. Row tap opens the app or a session. Further widget actions were deferred. **Documented.**
- No animated borders. Motion lives on the menu-bar icon and popover aura, not on the widget. **Observed.**
- No continuous refresh. Meaningful snapshot changes plus a 15-minute fallback. **Documented.**
- Tinted / Monochrome styles ignore blend modes and map luminance to prominence. Geometry over compositing. **Documented** in `tasks/lessons.md`.

### Visual acceptance rule for this milestone

If a healthy, single-session, or all-quiet widget looks busier or differently composed, the design has failed.

The allowed difference is: **when several sessions share one folder, they collapse into one existing row instead of repeating the same project name.**

---

## 3. Current Session / Data Architecture

```text
Provider hook / Codex thread/list
  → agenticglow-event helper
  → CursorHookPayload.normalized (Cursor only)
  → HookNormalizer.normalize
  → NormalizedEvent  (includes workingDirectory)
  → FileSessionStateStore.write  (~/Library/Application Support/AgenticGlow/Sessions/*.json)
  → AppModel.refresh every 2s
  → SessionResolver.resolve
  → SessionSnapshot  (workingDirectory dropped here)
  → popover SessionRowView
  → WidgetSnapshotBuilder.build
  → WidgetSessionSummary  (projectName only)
  → App Group WidgetSnapshot.json
  → widget SessionRow
```

### Current objects

| Type | Work-related fields | Where |
| --- | --- | --- |
| `NormalizedEvent` | `projectName`, `workingDirectory` (required, must start with `/`) | Core, persisted |
| `SessionSnapshot` | `projectName` only | Core, in-memory UI |
| `WidgetSessionSummary` | `projectName` only | Core, App Group |
| `ResolvedSessions` | flat session list, phase-sorted | Core |

`projectName` is already `URL(fileURLWithPath: cwd).lastPathComponent`, or the provider name if the basename is empty, `/`, or `.`. **Observed** in `HookNormalizer.projectName(for:provider:)`.

Codex discovery uses the same basename rule, except a missing folder on disk becomes `"Codex"` instead of the last path component. **Observed** in `CodexSessionDiscoveryAdapter`.

Cursor maps `conversation_id` → `session_id` and the first `workspace_roots[]` entry (or `tool_input.working_directory`) → `cwd`. Extra roots are discarded. **Observed** in `CursorHookPayload`.

### Current actions

| Action | Surface | Mechanism |
| --- | --- | --- |
| Open popover | Menu bar, shortcut, `agenticglow://open` | Existing |
| Activate source app | Popover row click, widget row link | `SourceApplicationActivator` |
| Codex window raise | Same click, Codex only | AppleScript, project-name substring |
| Hide row | Popover context menu Remove | Client-side hide |
| Refresh usage | Gear menu | Existing |
| Permission / quota notify | Notification Center | `NotificationPolicy` + `AgentNotificationService` |

There is no Reveal in Finder, no copy-context, no failed notification, no work grouping.

### Current attention

`SessionResolver` sort: permission > usingTool > thinking > failed > completed > disconnected > idle.

Widget `needsAttention` is only `.permission` or `.failed`. **Observed** in `WidgetSnapshotBuilder`.

Notifications fire only on the transition into `.permission`, plus quota low / exhausted. **Observed** in `NotificationPolicy` and `AgentNotificationService`.

---

## 4. `workingDirectory` Data-Flow Trace

Verified again on 2026-08-21 against current source and live session files.

```text
source
  Claude/Codex hook JSON field `cwd`
  Cursor `workspace_roots[0]` or `cwd` or `tool_input.working_directory`
  Codex `thread/list` field `cwd`
→ parser
  CursorHookPayload.normalized copies a path into `cwd`
  HookNormalizer requires `cwd` with prefix `/` or throws `.missingWorkingDirectory`
→ domain model
  NormalizedEvent.workingDirectory = cwd
  NormalizedEvent.projectName = lastPathComponent(cwd)
  validate() rejects missing `/` prefix or NUL
→ persistence
  FileSessionStateStore writes the full event, including workingDirectory
  Live files tonight still contain full paths. Observed.
→ resolver / view model
  SessionResolver.resolve builds SessionSnapshot
  and does not pass workingDirectory
  SessionSnapshot has no such property
→ widget
  WidgetSnapshotBuilder copies projectName, not the path
  WidgetSessionSummary has no workingDirectory
```

**The path disappears at `SessionResolver.resolve`, lines 85-98**, when `SessionSnapshot(...)` is constructed. Everything after that can only see the basename.

That is a one-field plumbing gap, not an architecture rewrite.

---

## 5. Proposed Work Identity

### Decision: Option A

**Work identity** = exact normalized working directory string.

**Work display name** = current `projectName` rule (folder basename), with a collision suffix only when two *visible* works share that basename.

### Why not git root (Option B)

Tonight a Claude session already lives in a worktree:

```text
/Volumes/Liquid/2DaMax Development/Caliber Wallet/.claude/worktrees/caliber-5-5a-composition-d702c0
```

**Observed.** Git-root grouping would merge that checkout with the main Caliber folder. Those are different working trees and should stay separate unless we later add branch intelligence. Phase 1 should not.

Git root also requires a filesystem walk, fails for deleted folders, and is unnecessary to prove the thesis.

### Why not workspace-root-or-git (Option C)

Cursor already collapsed multi-root workspaces to the first root. **Observed.** Promoting "workspace root" as a second identity kind would invent a field the other harnesses do not send. Codex and Claude send `cwd`. That is enough.

### Normalization (identity, not display)

Apply only cheap, local string rules. Do not talk to git.

1. Require prefix `/`.
2. Reject NUL and empty.
3. `URL(fileURLWithPath:).standardizedFileURL.path` to collapse `.`, `..`, and extra slashes.
4. Strip a trailing `/` except for `/` itself.
5. Do not lowercase. APFS is usually case-insensitive, but providers send a consistent path per session.
6. Do not resolve symlinks in Phase 1. Resolution needs the folder to exist and can surprise on `/tmp` and external volumes.
7. Do not require the folder to exist. A deleted or detached path still groups sessions that reported it.

### Display name

```text
Identity:  /Volumes/Liquid/2DaMax Development/AgenticGlow
Display:   AgenticGlow
```

If two active or widget-visible works share `AgenticGlow`, disambiguate the later one with its parent basename:

```text
AgenticGlow
AgenticGlow · 2DaMax Development
```

The widget stays one line of title. The identity never uses the display name.

### Unknown / missing path

`NormalizedEvent` already rejects a missing cwd. **Observed.** Codex discovery also skips threads whose cwd does not start with `/`. A session without work identity should not occur after a valid write. If a future adapter produces one, treat it as its own singleton work keyed by `provider:sessionID`, display `projectName` as today, and never merge it.

---

## 6. Grouping Rules

Two sessions are the same work when their normalized `workingDirectory` strings are equal.

| Situation | Group? | Why |
| --- | --- | --- |
| Same path, same harness | Yes | Same folder, two models or two conversations |
| Same path, different harnesses | Yes | This is the thesis. Tonight: Caliber Cursor + Claude share a path and a hashed id |
| Same repo, different branches, same cwd | Yes | Phase 1 cannot see the branch. That is acceptable. |
| Same repo, different worktrees | No | Paths differ. Do not merge. |
| Same parent directory, different project folders | No | Different identities |
| Nested subdirectory vs repo root | No | `/AgenticGlow` and `/AgenticGlow/Sources` are different work |
| Cursor multi-root workspace | First root only | Current Cursor adapter. Do not invent a union identity |
| Session cwd changes | Re-group on the latest event | Files are overwritten in place. Latest path wins |
| Completed / idle / failed | Still group while the row is visible | Resolver already drops them after 8s / 15s / hide |
| Unknown identity | Never group with others | Singleton |

**Branch awareness is not required for Phase 1.** Incorrect grouping that branch would prevent (two branches in one cwd) is rare for this toolchain: Cursor worktrees and Claude worktrees already change the path. **Observed.**

---

## 7. Edge Cases

| Case | Phase 1 behavior |
| --- | --- |
| Normal git repo | Identity = repo cwd the hook sent. Usually the folder the user opened. |
| Nested subdirectory | Separate work. Do not walk up to `.git`. |
| Monorepo | Separate work per cwd. Two packages in one repo stay two rows unless they share cwd. |
| Git worktree | Separate work. Path already differs. |
| Same folder name, different volumes | Different identities. Display disambiguates only if both are visible. |
| Renamed folder | New identity after the next hook. Old files age out in 24h. No migration table. |
| Deleted folder | Keep the last reported path. Display name stays the basename. Reveal in Finder fails silently. Codex discovery already substitutes `"Codex"` for display when the folder is gone; grouping still uses the stored path. |
| Detached / no process | Resolver already handles this. Grouping uses the stored path. |
| External volume | Paths like `/Volumes/Liquid/...` are valid and already used. **Observed.** |
| No working directory | Should not persist. If it appears, singleton, no merge. |
| Xcode opened from a parent | Identity is whatever cwd the agent reported. If that is the parent, it groups with other parent-cwd sessions. Do not special-case Xcode. |
| Cursor multi-folder workspace | First `workspace_roots` entry only. Document in Setup later if it confuses. Not a Phase 1 blocker. |
| Symlinks | No resolve. `/tmp/foo` and the real target are different identities. Revisit only if live data shows a collision. |
| Path spelling differences | Standardization handles `..` and trailing slashes. `//` becomes `/`. |

Do not build a project database to handle these. The session file already is the record.

---

## 8. Widget Information Hierarchy

Map the internal model onto the **existing row**, not a new hierarchy.

| Slot | Current field | Work-aware field | When it changes |
| --- | --- | --- | --- |
| Primary | `projectName` | Work display name | Same string for a single-session work. Unchanged. |
| Secondary | Phase label (medium) or `phase · provider` (large) | Meaningful status | Substituted only when a work group has 2+ sessions, or when the representative session needs you / failed |
| Tertiary | Provider on large only | Model or harness in that same secondary line | Only if it fits the current 12pt line and adds disambiguation |
| Trailing | Elapsed, if active | Elapsed of the representative session | Unchanged placement |
| Action | Implicit row `Link` | Same link, aimed at the representative session | No new button |

Never permanently show provider, harness, model, session id, attention, elapsed, and allowance on one row.

Allowance stays in the existing strip under the rows. It is not a work-row field.

---

## 9. Proposed Widget States

All of these reuse the current row and the current small headline. No extra panels.

### State A: One project, one active session

**UNCHANGED.**

```text
[brain]  AgenticGlow
         Thinking                    2m
```

Large: `Thinking · Cursor`.

Small: `1 session` / `active`.

This is the healthy default. Work identity is present underneath and invisible.

### State B: One project, multiple sessions

**SUBSTITUTED** secondary text. Same row chrome.

```text
[brain]  AgenticGlow
         3 active · Grok, Claude, Composer     2m
```

Large may say `3 active · Cursor` if all three are Cursor, because the harness is then obvious and the models carry the meaning.

Small, if every active session shares one work:

```text
[sparkle]
AgenticGlow          ← substituted for "3 sessions"
3 active             ← substituted for "active"
```

That is still one 28pt line and one 12pt line. Not a dashboard.

### State C: Multiple projects

Do **not** build a project list.

Medium still has two rows. Large still has 2-4. Use the existing `+ N more`.

```text
[brain]  AgenticGlow
         2 active · Grok, Claude
[brain]  Moodpaper
         1 active
+ 1 more
```

Small, multiple works: **UNCHANGED** `N sessions` / `active`. A small widget cannot name two projects without becoming a list.

### State D: Attention required

No banner. No Open button. The existing phase glyph and "Needs you" label already report this.

If one work needs you:

```text
[!]  AgenticGlow
     Needs you · 8m
```

Small already headlines attention count. If that count belongs to one work, substitute the 28pt line with the work display name and keep `needs you`. If several works need you, keep `N sessions` / `needs you`.

Row tap remains the action. Do not add a visible Open chip. That would be new chrome and a new App Intent surface the widget spec deferred.

### State E: Failed session

Existing red octagon and "Stopped while working". **UNCHANGED** for a single failed row.

```text
[x]  Moodpaper
     Stopped while working
```

If a work group contains a failure and also working sessions, the representative session is the failed one, secondary `Stopped while working`. Do not invent a mixed sentence on the widget.

### State F: Allowance constraint

**UNCHANGED widget.** The lowest-window bar already exists. Do not put `Codex constrained · Claude available` on a session row. That sentence belongs under ALLOWANCE in the popover, where both bars already sit.

A constrained pool does not by itself change widget row order.

### State G: Mixed state

This example is too dense for medium and for large-with-three-bars.

```text
AgenticGlow    Claude needs you
Moodpaper      Grok working
Proofstone     Codex reviewing
```

**Proposed compression:** attention-sort work groups, then the existing cap.

Medium shows 2 work rows. Large shows 3 when three allowance windows are present. The rest become `+ N more`.

If AgenticGlow needs you, it occupies row 1. Remaining healthy work shares row 2 or falls into `+ N more`. That is how the widget already behaves with sessions. **Observed** in `MediumWidgetView.maximumDisplayedSessions` and `LargeWidgetView.displayedSessionLimit`.

### State H: Everything is healthy

**This is the success state.**

- One quiet session: identical to today.
- Several sessions in one folder: one row instead of repeats. Calmer, not louder.
- Nothing active, no low allowance: small still says `All quiet`. Medium/large still say `No active or recent sessions` if the list is empty.
- Allowance bars, glass, type, spacing, icons: untouched.

The new model must not announce itself when there is nothing to correlate.

---

## 10. Visual Preservation Analysis

| Widget element | Classification | Notes |
| --- | --- | --- |
| Family sizes / canvas | UNCHANGED | No new families, no taller layout |
| Padding, 6pt/8pt stacks | UNCHANGED | |
| Session row HStack | UNCHANGED | Icon 18, 8pt gap, two text lines, elapsed |
| 14 / 12 / 11pt type | UNCHANGED | |
| Phase glyphs and colors | UNCHANGED | |
| Liquid Glass / containerBackground | UNCHANGED | |
| Allowance bars, pills, Tinted geometry | UNCHANGED | Frozen visual |
| Small 28pt headline | UNCHANGED structure | Copy may substitute a work name when one work owns the count |
| Medium/large attention banner | UNCHANGED (absent) | Do not bring it back |
| `+ N more` | UNCHANGED | |
| Row `Link` | UNCHANGED | Still the only widget action |
| Animated borders | UNCHANGED | Widget has none |
| Provider setup footer (large) | UNCHANGED | |
| Session list → work-compressed list | SUBSTITUTED | Same component, fewer rows when overlap exists |
| Secondary line for multi-session work | SUBSTITUTED | Replaces `Thinking` / `Thinking · Cursor` |
| Model names on the secondary line | CONDITIONAL | Only in a multi-session work row, and only as short slugs |
| Visible Open button | REMOVED from scope | Would be new chrome |
| Work section headers | REMOVED from scope | Would be a dashboard |
| Continuation sentence on the widget | REMOVED from scope | Popover only |
| Extra metadata rows | REMOVED from scope | |

**Popover** (not the widget, but in the same milestone): keep the 360pt glass popover. Do not add tabs or project cards. Optional CONDITIONAL cluster label only when two or more visible sessions share work. Individual session rows stay, because the popover is where the user picks *which* session to open.

That split is intentional:

- Widget: work → status → implicit open of the representative session
- Popover: work awareness in the summary, sessions still reachable

---

## 11. Attention Priority Model

Do not invent undetectable states.

### Signals that exist

| Signal | Source | Reliable? |
| --- | --- | --- |
| Needs you | `.permission` | Claude and Codex only. Cursor cannot. **Documented.** |
| Failed | `.failed` | Cursor `stop.status == error`; others inferred from mid-task death. **Observed.** |
| Working | `.thinking`, `.usingTool` | Yes |
| Completed | `.completed` | Visible 8s |
| Disconnected | `.disconnected` | Visible 15s |
| Idle | `.idle` | Yes |
| Constrained | allowance window `< 10%` or `0%` | Codex and Claude only. Cursor unknown. **Documented.** |
| Blocked | none | Do not invent. Cursor approvals are invisible. |

### Sort keys

1. Work group attention = the best (lowest) priority of its visible sessions, using the existing resolver order: permission > usingTool > thinking > failed > completed > disconnected > idle.
2. Constrained is **not** a session phase. It does not reorder widget rows. It only affects popover allowance copy and the existing menu-bar low-allowance badge.
3. Within the same attention, newest `updatedAt` first. Then provider name. Then session id. Current resolver already does this for sessions. **Observed.**
4. Widget rows are work groups in that order, capped by the existing family limits.
5. The representative session inside a group is the first session in that order. Deep links and elapsed time use that session.

### Emphasis

- Menu bar and notifications: permission (existing), failed (Phase 1 add).
- Widget: existing glyph and "Needs you" / "Stopped while working". No banner.
- Popover summary: may mention work name when one work owns the attention.

---

## 12. Model / Harness Presentation

Internal model may keep harness / provider / model. The widget should not.

| Situation | Secondary line |
| --- | --- |
| One session, any harness | Current copy. Medium: `Thinking`. Large: `Thinking · Cursor`. |
| Several sessions, same harness | `3 active · Grok, Claude, Composer` |
| Several sessions, mixed harnesses | `3 active · Grok, Claude, Codex` using **model slug if known, else harness display name** |
| Needs you, one session | `Needs you` |
| Failed, one session | `Stopped while working` |

Harness is worth showing when:

- the model is unknown, or
- two sessions share a model slug across harnesses (tonight's Claude-Grok / Cursor-Grok pair)

Otherwise hide the harness. Never show a raw provider enum plus a harness plus a model.

Slug shortening, **Proposed**: take the first token before `-` if the result stays recognizable (`grok-4.6` → `Grok`, `claude-sonnet-5-thinking-high` → `Claude`, `composer-2.5-fast` → `Composer`). Keep a small explicit map in Core. Unknown slugs show as-is, truncated to the line.

Provider names stay hidden on compact rows. Large already shows provider on single-session rows; leave that.

---

## 13. Last-Inch Action Matrix

Widget Phase 1 action: **the row link that already exists.** No new widget buttons.

Popover / notifications may add only what is reliable.

| Action | Phase 1 | Harness | Mechanism | Permissions | Failure | Safety | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Open session / app | Keep | All | Existing `activate(bundleIdentifier:projectName:)` | None beyond current | Silent fallback to no-op | Low | High |
| Open exact Codex window | Keep | Codex | `CodexWindowScript` matches window name containing `projectName` | One-time Apple Events for ChatGPT.app | Falls back to `activate()` | Low. Name match can miss or hit the wrong window if two titles share a basename | Medium-high for Codex, already shipped |
| Open exact Cursor session | Exclude as precision | Cursor | No documented session deep link in-repo. Third-party `cursor://file/...` exists; first-party docs were not found. CLI folder open can spawn extra windows. **Documented** community bugs. | Unknown | Easy to open the wrong or an extra window | Medium | Low. Do not fake it. |
| Open exact Claude session | Exclude as precision | Claude | No AppleScript dictionary. Generic activate only. **Documented** in `docs/privacy.md`. | None | App comes forward, not the session | Low | High that we cannot do better |
| Open workspace folder in Finder | Allow, popover only | All with a path | `NSWorkspace.activateFileViewerSelecting` on `workingDirectory` | None | Hide the item if the path is missing | Low | High |
| Copy work context | Allow, popover only | All | Pasteboard: display name, path, harness, model, phase, last updated. No prompts. | None | None | Low | High |
| Refresh usage | Keep | Codex, Claude | Existing gear action | Existing opt-in | Existing unavailable copy | Low | High |
| Dismiss / hide | Keep | All | Existing Remove | None | None | Low | High |
| Explain constraint | Allow as copy, popover | Codex, Claude | Continuation sentence under allowance | None | Must not name Cursor as available | Low | High if factual |
| Widget Open chip | Exclude | - | Would need App Intents, new chrome | - | - | - | Conflicts with widget spec |
| Approve / deny | Exclude | Claude/Codex only | Hook or app-server client | High | Unreliable hooks | High | Out |
| Reply / start / route / transfer | Exclude | - | - | - | - | High | Out |

**Open means:**

1. Widget row or popover row: activate the representative (or clicked) session's source app.
2. Codex: also try to raise the window whose title contains that session's `projectName`.
3. Claude / Cursor: bring the app forward. Do not claim "Open the AgenticGlow workspace in Cursor."
4. Finder reveal is a separate, explicit popover action, not the default Open.

If two works share a display name, Codex window raise already has that ambiguity. Passing the same `projectName` we pass today does not make it worse. Do not pass the full path into AppleScript unless we prove Codex window titles contain it.

---

## 14. Allowance Continuation Logic

### Known data

| Provider | Current window | Weekly | Model availability | Cursor pool |
| --- | --- | --- | --- | --- |
| Codex | Yes, often labeled Weekly only | Sometimes the only window | Partial | n/a |
| Claude | 5h + weekly | Yes | Partial | n/a |
| Cursor | None | None | Session model slug only | Not fetched. Must stay unknown |

**Observed** tonight: Claude weekly 1% left, Claude 5h 43% left, Codex weekly 54% left, no Cursor cache file.

### Valid comparisons

- Claude weekly vs Claude 5h: same product, two windows.
- Claude weekly vs Codex weekly: two known percentages. Factual.
- Anything vs Cursor: invalid. Cursor is unknown.

### Widget

**Do not add a continuation sentence.** The existing lowest-window bar already reports the tightest known constraint. Changing that caption would fight the frozen bar design and imply routing.

### Popover (Phase 1)

One quiet line under the existing bars, only when at least one known window is below 10% or at 0%.

Rules:

1. State facts, not advice.
2. Name only providers with known numbers.
3. Never say "use Codex" or "continue in Cursor."
4. If Claude is exhausted and Codex has room: `Claude weekly 1% left. Codex 54% left.`
5. If only Claude is low and Codex is off or missing: `Claude weekly 1% left.`
6. If Cursor is the only other live harness in that work: do not mention Cursor availability.
7. If both known providers are healthy: show nothing extra.

That is a continuation *picture*, not a router.

---

## 15. Notification Reliability

### Current triggers

**Observed** in `NotificationPolicy` and `AgentNotificationService`:

- Session newly entered `.permission`. Id: `permission.{session.id}`.
- Quota newly low (`< 10%`). Id: `quota.{provider}.{window}`.
- Quota newly exhausted (`0%`), replaces low for that window.

Not triggered: failed, stalled, completed, overlap, model change.

### Current failure modes

1. Failed sessions never notify. A 15-second failed row can die unseen if the popover is closed. **Observed.**
2. Notification click activates `sourceBundleID` only, not the session. **Observed.**
3. Cursor cannot enter `.permission`, so "needs you" notifications never fire for Cursor. **Documented.** Do not invent them.
4. `QuotaAlertTracker` is in-memory. A restart can re-announce a still-low window. **Inferred** from `AgentNotificationService` holding the tracker as an instance property.
5. Delivery is not verified. `UserNotificationCenter.add` is fire-and-forget. **Observed.**
6. Authorization is requested at start if either toggle is on, which is already the right pattern.

### Phase 1 smallest fix

1. Add `NotificationPolicy.newlyFailed` mirroring `newlyAwaitingPermission`.
2. Deliver once with id `failed.{session.id}`, title `{projectName} stopped while working`, body `{provider} stopped before finishing.`
3. Put `provider` and `sessionID` in `userInfo` for permission and failed. On click, resolve the live session and call `AppModel.activate(_:)`. If the session is gone, fall back to bundle activate.
4. Do not persist the quota tracker. Do not add delivery receipts. Do not notify on overlap or constraint.

That is enough for Test 2 without turning notifications into a second UI.

---

## 16. Progressive Disclosure

| Surface | Shows | Does not show |
| --- | --- | --- |
| Widget small | Count or, when one work owns the count, that work name + status word | Session list, models, actions, continuation |
| Widget medium / large | Existing rows, work-compressed when overlap exists; existing allowance bars | Headers, Open chips, harness ontology, continuation |
| Popover | Current session rows, optional one-line cluster hint when overlap exists; model on expand; continuation under bars; Reveal / Copy in the existing context menu | Project cards, tabs, history, diagnostics |
| Settings / Setup | Integrations, usage consent, existing toggles | Work graph |
| Notifications | Permission, failed, quota | Overlap, recommendations |

There is no main-app workspace window in Phase 1. AgenticGlow is still an accessory app. **Observed** in `AppDelegate`.

---

## 17. Implementation Architecture

Prefer extending current types. No project graph.

### New Core types (small)

```text
WorkIdentity
  rawPath: String
  value: String          // normalized path, used as grouping key

WorkPresentation
  identity: WorkIdentity
  displayName: String    // basename, plus parent if colliding among visible works

WorkGroup
  presentation: WorkPresentation
  sessions: [SessionSnapshot]   // already attention-sorted
  representative: SessionSnapshot
```

Pure functions:

- `WorkIdentity.normalize(path:)`
- `WorkGrouping.groups(from: [SessionSnapshot]) -> [WorkGroup]`
- `WorkDisplayName.disambiguate(_:visible:)`
- `WorkStatusLine.compact(for: WorkGroup) -> String`

### Data-flow change

```text
NormalizedEvent.workingDirectory
  → SessionSnapshot.workingDirectory   // stop dropping
  → WorkGrouping
  → popover summary / optional cluster
  → WidgetSnapshotBuilder
       still emits [WidgetSessionSummary]
       one summary per work group
       projectName = display name
       phase / provider / sessionID / elapsed / needsAttention
         copied from representative
       optional compactDetail (new, optional, default nil)
```

### Widget schema

Keep `WidgetSnapshot.sessions` as the row list so views do not change structure.

Add one optional field to `WidgetSessionSummary`:

```text
compactDetail: String?
```

When `nil`, `SessionRow` uses today's `PhaseGlyph.label` / `label · provider`. When set (multi-session work), it uses that string.

Bump `schemaVersion` to 2. Decode missing `compactDetail` as `nil` so an old snapshot still renders.

Do not add work arrays, tabs, or a second snapshot file.

### Popover

- `SessionListView.summary` may mention a single dominant work when overlap exists. Still one headline.
- Session rows stay. Sort by work attention, then current session priority, so siblings sit together.
- Context menu gains Reveal in Finder and Copy Context when `workingDirectory` is present.
- `AllowanceSectionView` gains the factual continuation line.

### Migration

- No file migration. Session JSON already has `workingDirectory`.
- Old in-memory snapshots do not exist across launches.
- Widget: unknown extra fields already decode permissively. **Documented.**

### What not to abstract

No `HarnessAdapter` rewrite, no `CapabilitySet` protocol, no task objects. Those are later phases. Phase 1 needs a path field, a normalize function, and a grouper.

---

## 18. Files / Components Likely Affected

### Must change

| File | Why |
| --- | --- |
| `Sources/AgenticGlowCore/State/SessionSnapshot.swift` | Add `workingDirectory` |
| `Sources/AgenticGlowCore/State/SessionResolver.swift` | Pass the field through |
| `Sources/AgenticGlowCore/Widget/WidgetSnapshot.swift` | Optional `compactDetail`, schema 2 |
| `Sources/AgenticGlowCore/Widget/WidgetSnapshotBuilder.swift` | Group, then build summaries |
| `Sources/AgenticGlowWidget/Views/SessionRow.swift` | Use `compactDetail` when present |
| `Sources/AgenticGlowWidget/Views/SmallWidgetView.swift` | Substitute work name only when one work owns the headline |
| `Sources/AgenticGlowApp/MenuBar/SessionListView.swift` | Summary; sibling ordering |
| `Sources/AgenticGlowApp/MenuBar/SessionRowView.swift` | Context menu actions |
| `Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift` | Continuation line |
| `Sources/AgenticGlowApp/Services/AgentNotificationService.swift` | Failed notify; richer click userInfo |
| `Sources/AgenticGlowCore/Notifications/NotificationPolicy.swift` | `newlyFailed` |
| `Sources/AgenticGlowApp/AppDelegate.swift` | Route notification click to `activate(session)` when possible |

### New, small, Core-only

| File | Why |
| --- | --- |
| `Sources/AgenticGlowCore/Work/WorkIdentity.swift` | Normalize |
| `Sources/AgenticGlowCore/Work/WorkGrouping.swift` | Group / representative / display |
| `Sources/AgenticGlowCore/Work/WorkStatusLine.swift` | Compact secondary copy |
| Matching `Tests/AgenticGlowCoreTests/Work/*` | Identity, grouping, copy |

### Tests that will need fixture updates

`SessionResolverTests`, `WidgetSnapshotBuilderTests`, `WidgetSnapshotTests`, `AppModelTests`, `SessionDetailPresentationTests`, any helper that constructs `SessionSnapshot`.

### Do not touch unless a compile forces it

`LiquidGlassSurface`, `PopoverAura`, `AllowanceBar` / `WidgetAllowanceBar`, `StatusItemController` motion, widget entitlements, hook installers, Cursor payload stripping.

---

## 19. Test Plan

### Identity (unit)

- Same path groups; trailing slash and `/./` still group.
- Different paths do not group, even with the same basename.
- Missing / invalid path is a singleton.
- Deleted path still groups by stored string.
- Worktree path does not merge with the main repo path.
- Two visible `AgenticGlow` folders get different display names.
- Symlink paths do not resolve (document the choice).
- Cursor first-root behavior stays covered in existing `CursorHookPayload` tests.

### Ordering (unit)

- Permission work sorts above working work.
- Failed is attention for the widget flag, not above an active tool-use session (keep current resolver order).
- Representative session is the first in that order.
- Cap still 8 in the snapshot, 2/3/4 on screen.
- `attentionCount` still counts sessions, not groups, so small's number stays honest if two sessions in one work both need you. **Keep current semantics** unless both are the same session. If two permission sessions share work, small should still say `2 sessions` / `needs you` if we are not substituting, or the work name plus `needs you` if that work owns every attention session.

### UI (widget previews + popover tests)

- One session: pixel-equivalent copy and layout fields.
- Many sessions, one work: one row, compact secondary.
- Attention, failed: existing glyphs, no banner.
- Constraint: bars unchanged; popover line only.
- No activity: All quiet / empty copy unchanged.
- Long display name: existing `lineLimit(1)`.
- Narrow small: existing 0.6 minimum scale.

### Notifications (unit)

- Idle → failed notifies once.
- Steady failed does not.
- Permission click userInfo can resolve a session id.
- Cursor never emits permission.

### Regression

- Existing Core widget tests (builder, formatting, freshness, deep link, schema).
- Privacy script: still no prompt fields.
- Allowance bars and Tinted geometry: no source edits, so no re-verification cycle unless we slip and touch them.
- Menu-bar motion and popover glass: do not edit those files.
- Widget registration script after any local install that happens later. Not this design pass.

### Visual baseline (before any implementation)

When implementation starts, capture the installed large, medium, and small widgets in Full Color and Tinted:

- idle / all quiet
- one working session
- two sessions, different folders
- current three-bar allowance layout

Compare after: size, spacing, type, card geometry, glass, idle density. The idle pair must be extremely close.

This design pass did not recapture those images. The baseline is the current installed 0.5.13-dev widget plus the source listed above. **Observed** process running; **not verified** as a fresh screenshot in this pass.

---

## 20. Regression Risks

| Risk | Why | Guard |
| --- | --- | --- |
| Widget looks busier when healthy | Extra labels or headers | Single-session path must use `compactDetail == nil` |
| Small headline truncates a long work name | 28pt on 170pt canvas | Keep `minimumScaleFactor`; prefer count when more than one work |
| Grouping hides a session the user wants to open | Widget opens representative only | Popover still lists every session |
| Duplicate Claude+Cursor id | Same hashed sid, two providers, same path | They group as one work; popover still shows two rows until a later collapse increment |
| Codex window raise misses | Still uses basename | No change to script unless proven |
| Reveal in Finder on a dead path | External volume unmounted | Fail silent, no error banner |
| Continuation implies routing | Easy to write "use Codex" | Copy review: facts only |
| Schema 2 breaks old widgets | Unlikely; decode is permissive | Default `compactDetail` nil |
| Touching allowance bar files | Tinted pill would regress | Do not edit those files |
| Failed notify noise | Inferred failures | Once per session id, same as permission |

---

## 21. Explicitly Deferred Features

- Persistent task identity
- Task orchestration, routing, handoff, auto-continue
- Agent replies, approve/deny
- Branch intelligence
- Build / test / git status
- Generalized project database
- New providers
- Major navigation or a main window
- Widget redesign, Open chips, App Intent actions
- Cursor usage scrape
- `cursor://file` workspace open
- CapabilitySet / harness adapter rewrite
- History / while-you-were-away
- Duplicate Claude+Cursor row collapse (related, not required to prove work grouping)
- Git symlink resolution

---

## 22. Implementation Sequence

Small, reviewable increments. Each should be mergeable alone.

### Increment 1: Pass the path through

Add `workingDirectory` to `SessionSnapshot` and `SessionResolver`. Update fixtures. No UI change.

Acceptance: unit tests see the path; popover and widget look identical.

### Increment 2: Identity and grouping, Core only

`WorkIdentity`, `WorkGrouping`, tests for the edge table. No UI.

### Increment 3: Popover awareness without new chrome

Sort siblings together. Summary may name one dominant work. Context menu: Reveal in Finder, Copy Context. Continuation line under allowance.

Acceptance: tonight's four AgenticGlow Cursor sessions sit together; Claude weekly 1% gets a factual line; widget unchanged.

### Increment 4: Widget compression

Builder emits one `WidgetSessionSummary` per work group. `compactDetail` only when `sessions.count > 1`. Small headline substitution only when one work owns the count.

Acceptance: Tests 1, 2, 4, 5. Visual compare against the baseline. Idle and single-session widgets match.

### Increment 5: Failed notification + click target

`newlyFailed`, session userInfo, activate the session if still live.

Acceptance: Test 2 for failure. No new widget chrome. Test 6 still holds.

Do not start Increment 4 until Increment 1 is green. The widget is the protected surface; give it the thinnest diff.

---

## 23. Acceptance Criteria

### Test 1

When multiple models or harnesses share a folder, the widget shows **one row** for that work, and the popover lists those sessions together. Faster to see the relationship than today's four identical `AgenticGlow` titles.

### Test 2

When a session needs the user, the widget row title is the work name and the subtitle is `Needs you`. The popover summary can say that work needs you. A notification names the work and opens the right app, and the session if still live.

### Test 3

Row tap still reaches the representative or clicked session. Popover can Reveal the folder and Copy context. No new widget button.

### Test 4

All quiet, and one healthy session, look like the current widget. No extra labels, no headers, no Open chip, no continuation on the bars.

### Test 5

Cursor rows never gain a fake "Needs you." Continuation never claims Cursor availability. Missing model stays "model unknown" only in popover expand, not as widget chrome.

### Test 6

No approve, deny, reply, start, route, or transfer shipped.

### Visual rule

If the healthy widget is substantially different or noticeably busier, the increment fails even if the tests pass.

---

## 24. Open Questions

1. If two permission sessions share one work, should small say `2 sessions` / `needs you` (honest count) or the work name / `needs you` (work object)? **Proposed:** work name when that work owns every attention session; otherwise keep the count.
2. Should the popover hide the second row of a Claude+Cursor duplicate id in this milestone, or only group them? **Proposed:** group only. Collapse is a later increment.
3. Codex window titles: do they ever contain more than the basename? Unverified. Do not change the AppleScript until someone checks a live title.
4. Is `composer-2.5-fast` shown as `Composer` or left as the slug? **Proposed:** `Composer`.
5. When implementation starts, who captures the three-family baseline screenshots, and on which desktop style (Full Color vs Tinted)? The design cannot claim a pixel baseline until those exist.
6. Should Reveal / Copy appear on the expanded detail panel, the context menu, or both? **Proposed:** context menu only, next to Remove, to avoid growing the expanded stack.

None of these block Increment 1.

---

## 25. Recommendation

Phase 1 is a plumbing and compression milestone, not a redesign.

The widget already has the right object in the title slot (`projectName`). It is just using a basename that cannot distinguish folders, and it repeats that basename once per session. Thread the path through, group on the normalized path, and substitute the secondary line only when a group has something to say.

Do not add git. Do not add a project database. Do not add widget chrome. Do not add a control plane.

The end state should feel like the AgenticGlow already in use, except that tonight's four Cursor rows in one folder become one calm row.

### Implementation sequence (if proceeding)

1. Pass `workingDirectory` into `SessionSnapshot`.
2. Add `WorkIdentity` / `WorkGrouping` with tests.
3. Popover sort, summary, Reveal, Copy, factual allowance line.
4. Widget group compression + optional small-headline substitute.
5. Failed notification + session-aware click.

---

**READY TO IMPLEMENT**
