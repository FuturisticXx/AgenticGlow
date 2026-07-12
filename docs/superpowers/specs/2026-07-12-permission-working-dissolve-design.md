# Permission + Working Dissolve — Menu Bar Icon Design

Date: 2026-07-12
Status: Approved by John

## Problem

`SessionResolver` gives the permission phase the highest priority. The moment
any session awaits permission, the menu bar collapses to the static yellow
`exclamationmark.circle.fill` and the spinning provider-colored hexagon (the
"agents are working" signal) disappears, even when other sessions are actively
thinking or using tools. John needs both facts visible at once: "a session
needs me" and "other agents are still working". Permission is the only phase
that can mask working sessions this way.

## Approved behavior

**Trigger.** Both must be true at the same time:

- At least one session is in `.permission`.
- At least one other session is in `.thinking` or `.usingTool`.

If permission is the only active state, the bar shows today's static yellow
exclamation, unchanged. If nothing needs permission, today's spinning icon is
unchanged.

**Presentation.** One icon slot, an 11-second repeating cycle:

| Segment | Duration | Shows |
|---|---|---|
| Working dwell | 6s | Spinning provider-colored hexagon (solid tint for one provider, orange-blue sweep for two, same rules as today) |
| Fade out | 1s | Cross-fade hexagon → yellow exclamation |
| Permission dwell | 3s | Static yellow `exclamationmark.circle.fill` |
| Fade in | 1s | Cross-fade exclamation → hexagon |

The rotation and color-sweep clocks never pause. The hexagon always fades back
in mid-spin, in phase; nothing restarts. The cross-fade is baked into the
per-frame `NSImage` the existing motion task already draws (both glyphs drawn
with complementary opacity). No new animation machinery, no symbol effects.

**Reduce Motion.** No dissolve, no spin: the static yellow exclamation, exactly
today's behavior. Permission is the more urgent state, so it wins when motion
is off.

**Accessibility.** The label reads both states, for example
"AgenticGlow, 1 session needs permission, 2 active sessions".

**Title.** Unchanged from today's permission behavior (count shown when more
than one session needs permission).

## Architecture

- `StatusPresentation` currently zeroes `activeProviders` when permission
  dominates. It will keep the working providers populated in the combined
  state and expose a flag for the pending permission (name at implementer's
  discretion, e.g. `pulsesPermission`), so `StatusItemController` knows to run
  the dissolve cycle.
- The dissolve timeline (elapsed seconds → hexagon opacity in 0...1) is a pure
  function so it can be unit tested without AppKit.
- `renderMotionFrame(at:)` composes the frame: rotated tinted hexagon at
  opacity `w`, yellow exclamation at opacity `1 - w`, drawn into the same
  18x18 image.

## Edge cases

- Celebration green still overrides everything for its 4 seconds
  (`celebrationResetTask` already gates the motion task).
- One working provider: solid provider color on the hexagon half of the cycle.
- Two working providers: existing capped orange-blue sweep.
- Permission count changes mid-cycle: title and accessibility label update;
  the cycle clock keeps running.

## Verification

- Unit tests lock the combined `StatusPresentation` state (providers kept,
  permission flag set, accessibility label mentions both).
- Unit tests lock the dissolve timeline function at segment boundaries and
  midpoints.
- Visual check: run the app with a mixed test fixture (permission + working)
  and pixel-sample the menu bar icon across one 11-second cycle to confirm
  both glyphs appear with a smooth transition.
