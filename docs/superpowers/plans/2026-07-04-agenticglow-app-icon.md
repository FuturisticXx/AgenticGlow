# AgenticGlow App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected application artwork with the approved A. Unified Spectrum icon and deliver a verified signed private release candidate.

**Architecture:** Use one deterministic 1024-pixel AppKit renderer as the source of truth, generate the existing macOS asset-catalog raster slots from that master, and leave the menu-bar symbol implementation unchanged. Verify source assets, the compiled bundle, Finder/Dock rendering, the signed DMG, and the private CI artifact as separate gates.

**Tech Stack:** Swift/AppKit, Xcode asset catalogs, XcodeGen, `xcodebuild`, `sips`, `codesign`, Apple notarization, Gatekeeper, GitHub Actions.

## Global Constraints

- Implement the exact A. Unified Spectrum design in `docs/superpowers/specs/2026-07-04-agenticglow-app-icon-design.md`.
- Keep the centered blue ring and short slanted blue-amber-green signal.
- Do not add glass, a waveform, orbit, status dots, ring-grid, text, or legacy radial blades.
- Do not change menu-bar symbols, interface layout, or product behavior.
- Preserve the untracked `docs/tasks/` directory and unrelated worktree content.
- Public publication remains disabled.

---

### Task 1: Deterministic Unified Spectrum Assets

**Files:**
- Create: `Scripts/generate-app-icon.swift`
- Create: `Scripts/verify-app-icon.sh`
- Modify: `Design/AgenticGlowIcon-1024.png`
- Modify: `Sources/AgenticGlowApp/Resources/Assets.xcassets/AppIcon.appiconset/*.png`

**Interfaces:**
- Consumes: approved geometry and colors from the design specification.
- Produces: `Scripts/generate-app-icon.swift <output-path>`, a reproducible master, and all required raster sizes.

- [ ] **Step 1: Add the failing verifier**

Create `Scripts/verify-app-icon.sh` with `set -euo pipefail`. It must:

1. Reject the current bad master SHA-256 `f3d4900ce6aa4d8b7444ca3e4407ad0371ac42e6643e6731299503922247c111`.
2. Confirm `Design/AgenticGlowIcon-1024.png` equals `icon_512x512@2x.png`.
3. Check the ten asset-catalog files against these dimensions:

```text
icon_16x16.png=16
icon_16x16@2x.png=32
icon_32x32.png=32
icon_32x32@2x.png=64
icon_128x128.png=128
icon_128x128@2x.png=256
icon_256x256.png=256
icon_256x256@2x.png=512
icon_512x512.png=512
icon_512x512@2x.png=1024
```

- [ ] **Step 2: Prove the verifier fails**

Run `Scripts/verify-app-icon.sh`.

Expected: nonzero exit because the current master has the rejected hash.

- [ ] **Step 3: Create the minimal renderer**

Create `Scripts/generate-app-icon.swift` using these locked values:

```swift
let canvasSize: CGFloat = 1024
let tileRect = CGRect(x: 32, y: 32, width: 960, height: 960)
let tileRadius: CGFloat = 218
let ringRect = CGRect(x: 271, y: 271, width: 482, height: 482)
let ringWidth: CGFloat = 58
let signalRect = CGRect(x: 350, y: 483, width: 324, height: 58)
let signalRotation = -8.0 * .pi / 180.0

let workingBlue = NSColor(srgbRed: 0.333, green: 0.667, blue: 1.000, alpha: 1)
let attentionAmber = NSColor(srgbRed: 1.000, green: 0.698, blue: 0.200, alpha: 1)
let completedGreen = NSColor(srgbRed: 0.208, green: 0.804, blue: 0.455, alpha: 1)
```

Draw only: transparent canvas, deep-neutral tile, restrained three-color edge light, crisp blue ring, and one rounded signal bar filled blue to amber to green. Encode a 1024-pixel PNG to the first command-line argument.

- [ ] **Step 4: Generate the raster set**

Run the renderer for `Design/AgenticGlowIcon-1024.png`, then use `sips -z` to generate each exact size listed in Step 1.

Expected: the master and all ten asset-catalog PNG files change.

- [ ] **Step 5: Verify and inspect**

Run `Scripts/verify-app-icon.sh`. Open the 1024, 128, 32, and 16 pixel files together.

Expected: exit 0; centered ring and signal; legible small sizes; no rejected geometry.

- [ ] **Step 6: Commit Task 1**

```bash
git add Scripts/generate-app-icon.swift Scripts/verify-app-icon.sh Design/AgenticGlowIcon-1024.png Sources/AgenticGlowApp/Resources/Assets.xcassets/AppIcon.appiconset
git commit -m "Replace app artwork with approved Unified Spectrum icon"
```

### Task 2: Compiled Icon And Runtime Verification

**Files:**
- Verify: `project.yml`
- Verify: `AgenticGlow.xcodeproj`
- Verify: `Sources/AgenticGlowApp/MenuBar/StatusPresentation.swift`
- Test: `Tests/AgenticGlowAppTests/StatusPresentationTests.swift`

**Interfaces:**
- Consumes: Task 1 asset catalog.
- Produces: a Release app bundle with the approved application icon and unchanged menu-bar identity.

- [ ] **Step 1: Verify deterministic project generation**

Run `xcodegen generate`, then `git diff --exit-code -- AgenticGlow.xcodeproj/project.pbxproj`.

Expected: no project-file diff.

- [ ] **Step 2: Build an isolated unsigned Release app**

```bash
rm -rf /tmp/agenticglow-icon-derived
xcodebuild -project AgenticGlow.xcodeproj -scheme AgenticGlow -configuration Release -derivedDataPath /tmp/agenticglow-icon-derived CODE_SIGNING_ALLOWED=NO build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Verify compiled resources**

Confirm `AppIcon.icns` and `Assets.car` exist in the built app, and `CFBundleIconFile` equals `AppIcon`.

- [ ] **Step 4: Verify menu-bar behavior is unchanged**

```bash
xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/StatusPresentationTests
```

Expected: tests pass; idle and working still use `circle.hexagongrid`.

- [ ] **Step 5: Inspect Finder and Dock**

Copy the isolated app to a temporary Applications folder, register it with Launch Services, and inspect Finder plus Dock at normal and magnified sizes. Remove only the temporary copy after inspection.

Expected: the approved geometry is centered and recognizable at every displayed size.

### Task 3: Signed Installer And Private CI

**Files:**
- Modify: `Cask/agenticglow.rb`
- Modify: `docs/release-checklist.md`
- Verify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: Task 2 compiled icon and configured Developer ID/notary credentials.
- Produces: corrected signed/notarized DMG and passing private CI artifact.

- [ ] **Step 1: Build the signed installer**

```bash
export AGENTICGLOW_NAME_CLEARED=1
export AGENTICGLOW_RELEASE_BUILD_APPROVED=1
export DEVELOPER_ID_APPLICATION='Developer ID Application: John Wright (Z52AX2BH7T)'
export NOTARY_PROFILE='agenticglow-notary'
Scripts/verify-release-gates.sh
Scripts/build-release.sh 0.1.0
Scripts/create-dmg.sh 0.1.0
Scripts/verify-release.sh 0.1.0
Scripts/generate-cask.sh 0.1.0 build/AgenticGlow-0.1.0.dmg
```

Expected: universal build, accepted notarization, valid staple, valid signatures, and Gatekeeper acceptance.

- [ ] **Step 2: Verify checksum and cask**

Run `shasum -a 256 build/AgenticGlow-0.1.0.dmg` and `ruby -c Cask/agenticglow.rb`.

Expected: cask checksum equals the DMG hash and Ruby reports `Syntax OK`.

- [ ] **Step 3: Record evidence**

Update `docs/release-checklist.md` with the design-spec path, compiled Finder/Dock result, notarization submission ID, and corrected DMG checksum. State explicitly that no public release was created.

- [ ] **Step 4: Commit release metadata**

```bash
git add Cask/agenticglow.rb docs/release-checklist.md
git commit -m "Record corrected AgenticGlow icon release candidate"
```

- [ ] **Step 5: Push and run private CI**

```bash
git push origin HEAD
branch="$(git branch --show-current)"
gh workflow run release.yml --ref "$branch" -f version=0.1.0
run_id="$(gh run list --workflow release.yml --branch "$branch" --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch "$run_id" --exit-status --interval 10
```

Expected: signing, notarization, verification, cask generation, and private artifact upload pass.

- [ ] **Step 6: Independently verify the artifact**

Download `AgenticGlow-0.1.0-private-rc` to `/tmp/agenticglow-icon-rc`; run `codesign --verify`, `xcrun stapler validate`, and `spctl -a -t open --context context:primary-signature` against its DMG.

Expected: valid signature, valid staple, and `source=Notarized Developer ID`.

- [ ] **Step 7: Final review**

Remove the temporary artifact, run `git diff --check`, `git status --short --branch`, and `gh release list --limit 5`.

Expected: only pre-existing `docs/tasks/` remains untracked and no public release exists.
