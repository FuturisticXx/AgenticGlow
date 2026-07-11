# AgenticGlow Liquid Glass Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live Glass Clarity control that enriches only AgenticGlow's native popover material while preserving all border and glow behavior exactly.

**Architecture:** Persist a normalized clarity value in `PreferencesStore`, map it through a pure `GlassAppearance` model, and render static adaptive layers in a focused `LiquidGlassSurface`. `SessionListView` consumes the surface only in its existing background; `PopoverAura` remains an independent untouched overlay.

**Tech Stack:** Swift 6, SwiftUI, Observation, XCTest, AppKit `NSPopover`, native macOS materials

## Global Constraints

- Deployment target remains macOS 14.0.
- New SDK symbols require compiler guards as well as availability checks.
- Do not modify `PopoverAura`, animated borders, glow colors, masks, timing, thickness, edge behavior, or `StatusItemController` animation logic.
- The slider minimum and default must reproduce the current AgenticGlow appearance.
- Use no third-party dependencies, shaders, custom blur loops, or continuous animation.
- Never use em dashes in source copy or documentation.

---

### Task 1: Persist Glass Clarity

**Files:**
- Modify: `Tests/AgenticGlowAppTests/PreferencesStoreTests.swift`
- Modify: `Sources/AgenticGlowApp/Settings/PreferencesStore.swift`

**Interfaces:**
- Produces: `PreferencesStore.glassClarity: Double`, constrained to `0...1`

- [ ] **Step 1: Write failing persistence tests**

Add tests proving a missing value defaults to `0`, assignments persist, and
values outside `0...1` clamp before storage.

- [ ] **Step 2: Verify the tests fail for the missing property**

Run:
`xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/PreferencesStoreTests`

Expected: compilation fails because `glassClarity` does not exist.

- [ ] **Step 3: Add the minimal preference implementation**

Add an observable `Double` property, persist it under `glassClarity`, default to
zero when absent, and clamp assignments to the closed unit interval.

- [ ] **Step 4: Verify focused tests pass**

Run the command from Step 2. Expected: all `PreferencesStoreTests` pass.

### Task 2: Model Adaptive Glass Layers

**Files:**
- Create: `Sources/AgenticGlowApp/MenuBar/GlassAppearance.swift`
- Create: `Tests/AgenticGlowAppTests/GlassAppearanceTests.swift`
- Modify: `project.yml`
- Regenerate: `AgenticGlow.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `GlassAppearance(clarity:colorScheme:reduceTransparency:)`
- Produces scalar layer properties for contrast scrim, top highlight, and depth

- [ ] **Step 1: Write failing model tests**

Test the current Dark Mode scrim opacity of `0.45` at clarity zero, zero added
Light Mode scrim at clarity zero, reduced scrim plus nonzero highlight and depth
at clarity one, clamping, and Reduce Transparency returning baseline values.

- [ ] **Step 2: Verify tests fail because the model is absent**

Run:
`xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/GlassAppearanceTests`

Expected: compilation fails because `GlassAppearance` does not exist.

- [ ] **Step 3: Implement deterministic mappings**

Use bounded linear interpolation with separate Light and Dark Mode constants.
Keep all values static and small enough to support, rather than imitate, native
Liquid Glass.

- [ ] **Step 4: Regenerate and verify**

Run `xcodegen generate`, then rerun the focused test command. Expected: pass.

### Task 3: Add the Live Settings Control

**Files:**
- Modify: `Sources/AgenticGlowApp/Settings/SettingsView.swift`
- Modify: `Tests/AgenticGlowUITests/AgenticGlowUITests.swift`

**Interfaces:**
- Consumes: `PreferencesStore.glassClarity`
- Produces: accessibility identifier `AgenticGlow.GlassClarity`

- [ ] **Step 1: Add a failing UI assertion**

Open Settings under the UI-test launch path and assert the Glass Clarity slider
exists with the stable accessibility identifier.

- [ ] **Step 2: Verify the UI test fails**

Run the single UI test. Expected: slider lookup times out.

- [ ] **Step 3: Add the settings section**

Add a labeled slider bound directly to `glassClarity`, displaying 0 through 100
percent and a concise caption that higher clarity reveals more background.

- [ ] **Step 4: Verify the focused UI test passes**

Run the single UI test again. Expected: pass.

### Task 4: Render the Material-Only Surface

**Files:**
- Create: `Sources/AgenticGlowApp/MenuBar/LiquidGlassSurface.swift`
- Modify: `Sources/AgenticGlowApp/MenuBar/SessionListView.swift`
- Modify: `project.yml`
- Regenerate: `AgenticGlow.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `PreferencesStore.glassClarity`
- Consumes: `GlassAppearance`
- Produces: static background layers only

- [ ] **Step 1: Build `LiquidGlassSurface` from the tested model**

Render the adaptive scrim and two static gradients. Read color scheme and Reduce
Transparency through SwiftUI environment values. Disable hit testing.

- [ ] **Step 2: Replace only the existing macOS 26 background branch**

Use `LiquidGlassSurface(clarity: preferences.glassClarity)` where
`darkModeScrim` currently appears. Preserve the macOS 14 through 25
`.regularMaterial` branch and leave the complete overlay block unchanged.

- [ ] **Step 3: Remove only obsolete surface code**

Delete `darkModeScrim`, `darkScrimOpacity`, and the now-unused `colorScheme`
environment property. Do not edit `PopoverAura`.

- [ ] **Step 4: Regenerate and run focused tests**

Run `xcodegen generate` and the full `AgenticGlowAppTests` bundle. Expected: pass.

### Task 5: Visual and Regression Verification

**Files:**
- Modify: `docs/superpowers/specs/2026-07-10-agenticglow-liquid-glass-design.md`
- Modify: `gotdone.md`

**Interfaces:**
- Consumes: completed feature and built application
- Produces: documented research, implementation, before/after notes, and proof

- [ ] **Step 1: Run the full non-UI suite**

Run:
`xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -skip-testing:AgenticGlowUITests`

Expected: all tests pass with zero failures.

- [ ] **Step 2: Run project verification**

Run `git diff --check`, `Scripts/verify-privacy.sh`, and a Debug build. Expected:
all exit zero.

- [ ] **Step 3: Capture visual evidence**

Launch the exact DerivedData product and capture the popover at clarity 0 and 100
in both Light and Dark Mode. Confirm clarity 0 matches baseline and clarity 100
shows more background, top illumination, and interior depth without reducing text
legibility.

- [ ] **Step 4: Audit the immutable boundary**

Compare the `PopoverAura` source block and `StatusItemController.swift` against
`main`. Expected: no behavioral diff. Confirm no clarity reference appears in
border, glow, or animation code.

- [ ] **Step 5: Document and commit**

Add the researched Apple behaviors, changed properties, before/after notes, test
results, and explicit border non-change confirmation to the design record and
`gotdone.md`. Commit only relevant files on `NewGlass`.

