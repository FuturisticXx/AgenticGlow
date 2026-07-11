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

