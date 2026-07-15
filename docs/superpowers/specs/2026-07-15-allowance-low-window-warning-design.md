# Allowance Low-Window Warning — Design

## Problem

The menu bar shows a small orange dot (`StatusItemController.badgeView`) whenever
`AppModel.hasLowAllowance` is true, which happens when any allowance window
(current or weekly, for either provider) has less than
`AllowanceWarning.thresholdPercentLeft` (10%) remaining.

Opening the popover after seeing the dot does not make the cause obvious: the
ALLOWANCE section renders every window's progress bar and percentage the same
way regardless of whether it's the one that triggered the dot. The user has to
scan every bar and compare against a threshold they don't see anywhere in the UI.

## Goal

When the popover is open, the specific window (or windows) that caused the dot
must be visually distinguishable at a glance, without adding a new color or
disturbing the existing per-provider bar coloring (Claude = orange, Codex =
blue).

## Approach

Reuse `AllowanceWarning.lowWindows(in:)` / `AllowanceWarning.thresholdPercentLeft`
— already the single source of truth the badge itself uses — at the row level
inside `AllowanceSectionView`.

For whichever window (current and/or weekly) is under the threshold, its caption
line switches from a plain secondary-colored `Text` to a `Label` with
`exclamationmark.triangle.fill`, colored `Color(nsColor: .systemOrange)` — the
same color already used for the menu bar dot, so the warning language is
consistent between the icon that draws the user in and the detail that explains
why. The provider-colored bar and pill above the caption are untouched: only the
caption text/icon beneath it changes.

Non-low windows keep their current plain-gray caption exactly as today.

## Changes

### `AllowancePresentation.swift`

Add two computed properties, evaluated directly against
`AllowanceWarning.thresholdPercentLeft` (not by re-deriving from
`lowWindows(in:)`'s label strings, to avoid a string-matching dependency):

```swift
let currentIsLow: Bool
let weeklyIsLow: Bool
```

```swift
currentIsLow = (allowance.currentPercentLeft ?? .infinity) < AllowanceWarning.thresholdPercentLeft
weeklyIsLow = (allowance.weeklyPercentLeft ?? .infinity) < AllowanceWarning.thresholdPercentLeft
```

Update the existing `spoken(...)` helper (used for both
`accessibilityCurrent` and `accessibilityWeekly`) to accept an `isLow: Bool`
parameter and append `"low"` to the joined parts when true, so VoiceOver users
get the same signal sighted users get from the triangle icon.

### `AllowanceSectionView.swift`

In `allowanceContent(_:freshness:)`, replace:

```swift
Text(presentation.currentDetail)
    .font(.caption)
    .foregroundStyle(.secondary)
```

with a conditional: when `presentation.currentIsLow`, render

```swift
Label(presentation.currentDetail, systemImage: "exclamationmark.triangle.fill")
    .font(.caption.weight(.semibold))
    .foregroundStyle(Color(nsColor: .systemOrange))
```

otherwise keep the existing plain `Text`. Apply the same conditional treatment
to the weekly caption (`weeklyCaption(presentation)`), gated on
`presentation.weeklyIsLow`.

## Out of scope

- No change to the threshold value, the badge dot itself, or notification
  logic — this only affects what the popover shows once opened.
- No change to bar/pill coloring (provider identity stays primary).
- No new SF Symbol or color introduced; both already exist in the codebase.

## Testing

Extend `Tests/AgenticGlowAppTests/AllowancePresentationTests.swift`:
- `currentIsLow` is `false` at exactly the threshold and above, `true` just
  below it (boundary cases at 10% and 9.99%).
- `weeklyIsLow` mirrors the same boundary behavior independently of `currentIsLow`.
- `accessibilityCurrent` / `accessibilityWeekly` contain `"low"` when the
  corresponding flag is true, and do not when false.

No UI test changes required — this is a caption-level visual change on an
existing accessibility-identified view; live verification via the `both-working`
or a low-allowance fixture is sufficient (see plan).
