# Menu bar icon style setting

Date: 2026-07-25
Status: approved

## Problem

While an agent works, the menu bar icon spins in its provider's color:
orange for Claude, blue for Codex, cross-fading between the two when both
are working. Some users want a menu bar that reads as calm and matches
every other icon up there, rather than one carrying a saturated color for
minutes at a time.

## Goal

Offer a setting that switches the working icon between today's
provider-colored animation and a monochrome icon that adapts to the menu
bar's current background, black on a light bar and white on a dark one.

## Scope

Monochrome affects **only the working icon**. These keep their colors in
both modes, because they carry meaning rather than provider identity:

- The yellow `exclamationmark.circle.fill` shown when a session needs the
  user.
- The green celebration icon on a weekly reset.
- The orange low-allowance badge dot.

Out of scope: the popover, the widget, session row colors, and any change
to rotation speed or the animation itself.

## Approach

Render the monochrome icon as a **template image** (`isTemplate = true`,
no palette configuration) and let macOS flatten it to the menu bar's
current tone.

The rejected alternative was reading the existing `barAppearance` value
and baking `NSColor.black` or `.white` in by hand. It reimplements what
the system already does, and it gets two documented traps wrong:

- macOS dims menu bar content on inactive displays. A hand-picked white
  icon does not dim, so it would look correct on the active display and
  wrong on every other one (`tasks/lessons.md`, "Verify menu bar visuals
  on the ACTIVE display only").
- The bar's light/dark verdict can lag a wallpaper change. A template
  icon lags in lockstep with every other menu bar icon, so it never looks
  out of step; a hand-tinted one can disagree with its neighbours.

## Design

### Preference

`PreferencesStore` gains `menuBarIconStyle`, an enum with cases `color`
and `monochrome`, persisted under the `menuBarIconStyle` key as a raw
string. It defaults to `color`, so no existing user's icon changes on
upgrade. It follows the existing `didSet`-writes-to-defaults pattern and
is included in `reconfigure(defaults:showTimerDidChange:)` alongside the
other keys.

### Settings UI

A picker in the existing `Section("Appearance")` of `SettingsView`,
above Glass Clarity:

```
Menu bar icon    [ Color | Monochrome ]
```

Segmented style, with a caption below it reading "Monochrome matches the
menu bar's own black or white." Carries an accessibility identifier
(`AgenticGlow.MenuBarIconStyle`) for UI testing, matching the Glass
Clarity slider's convention.

### Rendering

`StatusItemController` stores the `PreferencesStore` it is already handed
in `init`, and reads `menuBarIconStyle` inside the existing frame task
rather than observing it. This follows the rule established in
`tasks/lessons.md` ("effectiveAppearance KVO storms with self-rendering
status items"): anything redrawn by a frame task reads environment state
inside that task, so a change applies within a frame with nothing to
storm.

`symbolImage(_:color:rotatedDegrees:)` gains a template path. When the
style is monochrome and the icon being drawn is the working hexagon, it
builds the symbol with no `SymbolConfiguration` and sets `isTemplate =
true` on both the base image and the rotated output. Rotation is
unaffected: it is baked geometry, independent of color.

The colored states listed under Scope continue to take the existing
non-template path in both modes. Because the frame task rebuilds the
image every frame anyway, alternating between template and non-template
images across states costs nothing and cannot restart a symbol effect
(there are none; rotation is our own).

### Behavior change worth naming

In color mode with both providers working, the icon slowly cross-fades
blue to orange. Monochrome has nothing to fade between, so that sweep
stops and only the rotation remains. Both-providers and one-provider look
identical in monochrome. This is intended for a calm mode, but it is a
behavior change rather than a pure recolor.

## Testing

- `PreferencesStore` round-trips `menuBarIconStyle` through
  `UserDefaults`, defaults to `color` when absent, and picks it up in
  `reconfigure`.
- The icon builder returns a template image for the monochrome working
  icon and a non-template colored image otherwise.
- Live verification on the **active** display in both a light and a dark
  menu bar, per `tasks/lessons.md`. Preview and offscreen rendering do
  not count for menu bar tone.

## Risks

- Template flattening could in principle lose internal symbol detail. It
  does not here: `circle.hexagongrid` is already drawn with a single
  palette color, so monochrome is the identical shape in a different
  tone. Confirmed by rendering the real symbol both ways before writing
  this spec.
- If a future icon state uses multiple palette colors, it must stay on
  the non-template path or it will flatten to a silhouette.
