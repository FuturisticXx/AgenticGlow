# Global Popover Shortcut + Auto-Restart After Repair — Design

## Problem

Two separate requests:

1. AgenticGlow has no keyboard shortcut to open the menu bar popover. It can
   only be opened by clicking the menu bar icon.
2. Setup's Repair action (for Claude or Codex) can trigger a real, reproducible
   AppKit-level crash (confirmed this session via AddressSanitizer bisection —
   it reproduces identically with and without the self-heal feature, so it's a
   pre-existing OS bug outside app code, most likely tied to the current macOS
   26 beta, not something fixable in AgenticGlow's own code). When it fires,
   the app vanishes with no explanation, which reads as broken.

## Goal

1. A global keyboard shortcut toggles the popover open/closed from any app,
   the same way clicking the menu bar icon does.
2. After a successful Repair, AgenticGlow restarts itself on purpose, with a
   brief visible message, before the latent crash has a chance to fire —
   turning an unexplained disappearance into a deliberate-looking restart.

## Non-goals

- Fixing the underlying AppKit crash itself. It's outside app code; this
  design only prevents the user from seeing it during the one flow (Repair)
  where it's been reproduced.
- Any change to `install()` or `remove()` — only `repair()` triggers a
  restart, matching the flow the crash reports actually show.
- Making the global shortcut configurable. It's a fixed combo for now.

## Decisions made during brainstorming

- Shortcut is **Command+Shift+A**, not Control+A. Control+A is macOS's
  near-universal Emacs-style "move to beginning of line" text-editing
  shortcut; a true global hotkey registration would intercept it system-wide
  in every text field, in every app, for as long as AgenticGlow is running.
  Command+Shift+A has no competing system-wide meaning.
- The shortcut **toggles** the popover (open if closed, close if open) —
  matching "same as clicking the menu bar icon," not an open-only action.
- The restart shows a brief "Repair successful — restarting AgenticGlow…"
  message (~1.5s) before relaunching, rather than an instant, unexplained
  disappearance.
- After relaunch, Setup **automatically reopens** showing the real
  (already-successful) install state, rather than leaving the user to infer
  success from the menu bar alone.

## Approach

### 1. Global hotkey via Carbon `RegisterEventHotKey`

`AppDelegate.swift` already has an unused `import Carbon` from earlier work.
Carbon's `RegisterEventHotKey` claims a global hotkey exclusively — no
Accessibility/Input Monitoring permission prompt needed, unlike an
`NSEvent` global monitor (which also wouldn't claim the combo exclusively,
just observe it). `AppDelegate` registers `kVK_ANSI_A` + Cmd+Shift in
`applicationDidFinishLaunching` (skipped when running under a UI-test
fixture, matching how other real-environment-only wiring in this file is
already gated) and unregisters it in `applicationWillTerminate`. On trigger,
it calls a new non-private method on `StatusItemController` that performs
the same toggle logic as a real click (`togglePopover()` today is `private`;
it becomes internal so `AppDelegate` can call it, no behavior change).
Registration failure (rare — e.g. another app already claimed the combo) is
logged and silently ignored; the popover remains reachable by click either
way.

### 2. Setup reflects real status on open

Today, `SetupViewModel.phase` always starts at `.ready` (or `.unavailable`)
regardless of whether hooks are actually already installed — reopening
Setup after a successful install currently shows a stale "Ready" state
until the user clicks Install/Repair again. `SetupView`'s existing `.task`
(which currently only calls `detectVersion()`) gains a matching call to a
new `SetupViewModel` method that checks `integration.status()` and sets
`phase` to `.installed`, or `.needsTrust` for Codex when trust review is
still outstanding, when hooks are already present. This is what lets a
reopened Setup window — whether reopened normally by the user or reopened
automatically after our restart — show the truthful state with no
restart-specific special case.

### 3. Auto-restart after a successful Repair

`SetupViewModel.repair()` gains one more step after `integration.repair()`
succeeds:

1. Set a new `SetupPhase.restarting` case. `SetupView` shows "Repair
   successful — restarting AgenticGlow…" for this phase.
2. `try? await Task.sleep(for: .seconds(1.5))`.
3. Call a new injected `requestRestart: () -> Void = { }` closure (same
   optional-closure pattern already used for `setIntegrationEnabled`).

`install()` and `remove()` are untouched — only `repair()` calls
`requestRestart`.

`AppDelegate` wires `requestRestart` for both the Claude and Codex
`SetupViewModel` instances to a shared method that:

1. Sets a one-shot `UserDefaults` flag, `reopenSetupAfterRestart`.
2. Calls `NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL,
   configuration:)` with `configuration.createsNewApplicationInstance =
   true` (without this flag, launching an already-running app just
   activates the existing process instead of spawning a genuine second
   instance — the opposite of what a self-relaunch needs).
3. Only calls `NSApp.terminate(nil)` after that launch call succeeds. If it
   throws, the current instance stays running rather than leaving the user
   with no app at all — a launch failure is a soft failure, not a reason to
   also kill the only running copy.

On the next launch, `applicationDidFinishLaunching` reads and clears
`reopenSetupAfterRestart`; if it was set, it calls the existing
`showSetupWindow()` regardless of the normal `completedSetup` gate. Because
of point 2 above, the reopened Setup window shows the real, already-correct
state — no fake "just repaired" UI needs to be reconstructed across the
process boundary.

## Testing

- Unit tests (same `SetupRecorder`-based pattern as the existing
  `SetupViewModelTests`): `repair()` transitions through `.restarting`
  before calling `requestRestart`; `requestRestart` is not called on
  `install()` or `remove()`; the new status-check method correctly derives
  `.installed`/`.needsTrust`/no-op from a mocked `status()`.
- The Carbon hotkey registration and the actual process relaunch are
  OS-level side effects not practically unit-testable. Verified live:
  trigger Command+Shift+A from another app and confirm the popover toggles;
  trigger a real Repair and confirm the app relaunches with Setup showing
  the correct installed state, without the crash being visible.

## Error handling

- Hotkey registration failure: logged, silently skipped, popover still
  reachable by click.
- Restart launch failure: current instance stays alive; repair itself
  already succeeded (hooks are already correctly written to disk) so
  nothing about the actual integration state is lost.
