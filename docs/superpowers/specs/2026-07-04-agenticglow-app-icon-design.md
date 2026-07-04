# AgenticGlow App Icon Design

## Goal

Replace the current application icon with the approved **A. Unified Spectrum** design while preserving the existing menu-bar status icon behavior.

## Approved Design

The application icon uses one centered pulse on a flat, deep-neutral tile.

- A circular pulse ring is optically centered in the square canvas.
- A short slanted signal crosses the center of the ring.
- The signal contains the existing status colors in this order:
  - working blue
  - attention amber
  - completed green
- The ring uses the same blue as the working state, with restrained blue, amber, and green light around its edge.
- The icon contains no text.

The approved visual is the original **Unified Spectrum** browser mockup shown before any glass refinement. Later glass, waveform, orbit, status-light, ring-grid, and Prism Pulse concepts are rejected.

## Geometry

- Canvas: square, 1024 by 1024 pixels at master size.
- The primary ring and internal signal share one visual center.
- The primary mark occupies roughly half the canvas width, leaving generous system-safe space.
- The signal is a single rounded bar with a restrained forward slant.
- The silhouette must remain recognizable at 16, 32, 64, 128, 256, 512, and 1024 pixels.

## Color

- Tile: deep neutral charcoal, not pure black.
- Working blue: dominant ring and leading signal color.
- Attention amber: middle signal color and restrained edge light.
- Completed green: trailing signal color and restrained lower edge light.
- Colors remain distinguishable without excessive saturation or bloom.

## Material And Effects

- Preserve the flat, polished appearance of the approved mockup.
- Do not add glass layers, translucent lenses, bevels, specular streaks, or new three-dimensional geometry.
- Glow is restrained and supports the three status colors; it must not obscure the ring or signal.
- Do not add baked system shadows outside the icon tile.

## Platform Behavior

- The application icon changes only the Finder, Dock, installer, and application-bundle artwork.
- The menu-bar icon remains the existing monochrome `circle.hexagongrid` symbol and retains its current state behavior.
- The macOS asset catalog remains the source of all required raster sizes.

## Implementation Constraints

- Replace the current rejected icon master and every generated `AppIcon.appiconset` raster.
- Generate smaller sizes from the approved master, then inspect 16, 32, 64, 128, 512, and 1024 pixel output.
- Do not change product behavior, interface layout, menu-bar symbols, or unrelated assets.
- Preserve unrelated worktree changes and the untracked `docs/tasks/` directory.

## Verification

1. Confirm every asset-catalog file has its required dimensions.
2. Build the Release application and confirm `AppIcon.icns` and `Assets.car` are present.
3. Inspect the compiled icon at Finder, Dock, 16-pixel, 32-pixel, and 512-pixel sizes.
4. Verify the menu-bar icon and its tests are unchanged.
5. Build a signed, notarized DMG and verify its signature, staple, and Gatekeeper status.
6. Run the private release-candidate workflow and verify the uploaded artifact contains the approved icon.

## Acceptance Criteria

- The application icon visually matches the approved Unified Spectrum mockup.
- The ring and signal are centered and legible at all required sizes.
- Blue, amber, and green match the app's existing status language.
- No rejected visual concept appears in the final icon.
- The corrected signed installer passes local and private CI release verification.
