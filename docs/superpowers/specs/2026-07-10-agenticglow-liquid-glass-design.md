# AgenticGlow Liquid Glass Clarity Design

## Goal

Make the existing AgenticGlow popover material feel clearer, deeper, and more
responsive to its background while preserving the animated border and glow
behavior exactly.

## Apple Design Basis

Apple describes Liquid Glass as a distinct functional layer that floats above
content. It bends and concentrates background light through lensing, reflects
surrounding color, adjusts tint and shadow for legibility, and becomes lighter
or darker based on the content beneath it. The regular variant prioritizes
legibility through blur and luminosity adjustment. The clear variant prioritizes
background visibility and can require a dimming layer over bright content.

AgenticGlow already receives the native system popover material on macOS 26 and
later. Its custom surface currently adds only a fixed 45 percent black scrim in
Dark Mode. That fixes washout, but it is binary and visually flat: it has no
adjustable transmission, no internal illumination, no surface depth cue, and no
Light Mode treatment. Replacing the native material would work against Apple's
adaptive implementation, so AgenticGlow will preserve it and add only restrained,
static layers above it.

## User Control

Settings gains a **Glass Clarity** slider with a range of 0 through 100.

- 0 is the exact current/default AgenticGlow surface.
- 100 is the clearest treatment while retaining enough adaptive contrast for
  session text and controls.
- Changes persist in `UserDefaults` and appear immediately in the open popover.
- The default is 0 so existing users see no visual change until they opt in.
- VoiceOver identifies the value as a percentage and explains that higher values
  reveal more of the background.

"Glass Clarity" follows Apple's preference for describing the user-visible
result instead of exposing implementation details such as blur radius or alpha.

## Architecture

`GlassAppearance` is a pure, app-layer value that accepts normalized clarity,
color scheme, and Reduce Transparency state. It returns calibrated values for
three material-only layers:

1. An adaptive contrast scrim that decreases as clarity rises.
2. A quiet top-to-bottom illumination gradient that suggests reflected ambient
   light and surface curvature.
3. A subtle interior depth gradient that keeps the lower surface grounded.

`LiquidGlassSurface` owns those layers and is used only inside
`SessionListView.background`. It uses simple SwiftUI fills and gradients so it
does not add continuous rendering, custom shaders, or another blur pass. The
system popover remains responsible for native blur, refraction, background
sampling, and macOS 27 adaptation.

When Reduce Transparency is enabled, `GlassAppearance` resolves to the current,
more opaque baseline regardless of the slider, preserving accessibility and
legibility.

## Immutable Border Boundary

`PopoverAura` remains a separate `SessionListView.overlay`. This feature does not
modify its gradients, masks, widths, blur radii, opacity values, animation timing,
motion state, or activation behavior. It also does not modify
`StatusItemController` or any menu bar animation code. The clarity preference is
consumed only by `LiquidGlassSurface`.

## Compatibility and Performance

- Deployment remains macOS 14.
- macOS 26 and later use the system Liquid Glass popover plus the adaptive custom
  surface layers.
- macOS 14 through 25 retain `.regularMaterial`; the clarity control does not
  pretend to reproduce unavailable system Liquid Glass there.
- No third-party dependency, timer, shader, custom blur, or per-frame work is
  introduced.
- Light Mode and Dark Mode use separate calibrated contrast and illumination
  values.

## Verification

- Unit tests prove default persistence, clamping, live preference mutation, and
  deterministic light/dark/accessibility appearance values.
- The focused app test bundle and full non-UI test suite must pass.
- A source diff audit must prove that `PopoverAura` and `StatusItemController`
  behavior did not change.
- Light and Dark Mode screenshots at clarity 0 and 100 provide before/after visual
  evidence from the built app.

## Implemented Changes

- Added a persisted `Glass Clarity` setting with a 0 through 100 percent slider.
- Added a pure `GlassAppearance` mapping with separate Light and Dark Mode values
  for contrast, illumination, interior depth, and a restrained specular cue.
- Added `LiquidGlassSurface` as a static layer above the native popover material.
- Preserved the exact current appearance at 0 percent clarity: Dark Mode retains
  the 45 percent black scrim and Light Mode adds no custom layer.
- Added a Reduce Transparency override that resolves to the current baseline.
- Retained `.regularMaterial` unchanged on macOS 14 through 25.

## Before and After

| Before | After | Why |
| --- | --- | --- |
| Fixed 45 percent Dark Mode scrim | Scrim decreases continuously from 45 to 16 percent | More background transmission at higher clarity without discarding the proven legibility floor |
| No custom Light Mode surface treatment | Restrained illumination, depth, and specular layers appear as clarity rises | Adds dimensional cues while the native material remains responsible for adaptation and blur |
| Binary Light Mode versus Dark Mode behavior | Independently calibrated Light and Dark Mode optical values | Keeps the surface controlled across contrasting backgrounds |
| No user control | Live, persisted Glass Clarity slider | Lets users choose between the exact current default and a clearer presentation |
| Accessibility setting did not influence custom glass | Reduce Transparency restores the current baseline | Respects the user's legibility preference |

## Verification Record

- Baseline non-UI suite passed before implementation.
- `PreferencesStoreTests`: 6 passed, 0 failures.
- `GlassAppearanceTests`: 4 passed, 0 failures.
- `AgenticGlowAppTests`: 63 passed, 0 failures after the isolated test mode was
  added, including all four `VisualQALaunchConfigurationTests`.
- Full non-UI scheme passed with zero failures.
- Debug build and `Scripts/verify-privacy.sh` exited successfully.
- XcodeGen regeneration produced an identical project file.
- The entire `PopoverAura` source block is byte-identical to `main`.
- `StatusItemController.swift` is byte-identical to `main`.
- No glass preference or surface type is referenced by animation code.
- UI automation could not initialize twice because macOS timed out enabling
  automation mode. A dedicated `--visual-qa` mode now replaces real credentials
  with an in-memory store, uses isolated preferences and empty session data,
  disables real provider and update activity, applies explicit appearance and
  clarity arguments, and opens the native popover automatically.
- Four native-popover captures completed without a Keychain prompt: Dark Mode at
  0 and 100 percent clarity, and requested Light appearance at 0 and 100 percent.
- The 0 percent Dark Mode capture retained the existing dense, legible surface.
  At 100 percent, more of the underlying color transmitted through while text,
  controls, top illumination, and lower depth remained clear.
- Over the dark, visually rich test background, the native popover remained dark
  even when the app requested Light appearance. This verified the system
  material's background-responsive adaptation instead of a forced flat light
  fill; both endpoints remained premium and legible.
- The final test build compiled with code signing disabled and launched no test
  host. Privacy verification, deterministic XcodeGen, and diff formatting passed.
- The final non-UI suite also ran with ad-hoc signing and
  `AGENTICGLOW_ISOLATED_TEST_MODE=1`; it passed without Keychain access or a
  password prompt.
- The only `StatusItemController` addition is a visual-QA entry point that calls
  the existing popover toggle. No existing border, glow, timing, or animation
  line changed.

## Live Preview Calibration Follow-up

- Live observation was verified directly: changing `glassClarity` invalidates
  observers immediately.
- Initial screenshot calibration showed the higher-clarity highlight and depth
  layers replacing too much of the opacity removed from the scrim, making the
  slider's effect technically present but visually too subtle.
- Maximum Dark Mode clarity now removes the custom scrim completely. Highlight,
  depth, and specular layers were reduced so they add dimension without masking
  the increased transmission. The 0 percent baseline remains unchanged.
- Settings now includes a compact `GlassClarityPreview` built from the same
  production `LiquidGlassSurface`. It updates while the slider is dragged, so
  users can see the effect even though opening Settings closes the transient
  menu-bar popover.
- Final isolated non-UI verification passed 64 app tests with zero failures.
