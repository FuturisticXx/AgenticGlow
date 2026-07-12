# Permission + Working Dissolve Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a session awaits permission while others are working, the menu bar icon alternates on a calm 11-second dissolve between the spinning provider-colored hexagon and the yellow exclamation, instead of hiding the working state.

**Architecture:** A pure timeline function (`PermissionDissolve`) maps motion-clock seconds to the hexagon's opacity. `StatusPresentation` keeps the working providers populated in the combined state and exposes `pulsesPermission`. `StatusItemController`'s existing 30fps motion task composes both glyphs into the per-frame image with complementary opacity; no new animation machinery.

**Tech Stack:** Swift, AppKit (NSImage composition), XCTest, XcodeGen project (`AgenticGlow.xcodeproj` already generated).

Spec: `docs/superpowers/specs/2026-07-12-permission-working-dissolve-design.md`

## Global Constraints

- Cycle: 6s working dwell, 1s fade out, 3s permission dwell, 1s fade in (11s total), from the approved spec.
- Reduce Motion shows today's static yellow exclamation; no dissolve, no spin, no provider tints.
- Rotation and color-sweep clocks never pause or restart across dissolve segments.
- Permission glyph is `exclamationmark.circle.fill` in `.systemYellow`; working glyph is `circle.hexagongrid` colored by the existing provider rules.
- Accessibility label in the combined state reads both facts, e.g. "AgenticGlow, 1 session needs permission, 2 active sessions".
- Unit tests run with `CODE_SIGNING_ALLOWED=NO` (keychain-prompt lesson in tasks/lessons.md). Do NOT disable signing for UI test targets.
- No em dashes in any prose or comments.

---

### Task 1: PermissionDissolve timeline

**Files:**
- Create: `Sources/AgenticGlowApp/MenuBar/PermissionDissolve.swift`
- Test: `Tests/AgenticGlowAppTests/PermissionDissolveTests.swift`

**Interfaces:**
- Consumes: nothing (pure Foundation).
- Produces: `enum PermissionDissolve` with `static let workingDwell: Double`, `static let fade: Double`, `static let permissionDwell: Double`, `static var cycle: Double`, and `static func workingOpacity(at seconds: Double) -> Double` returning 0...1 (1 = hexagon fully visible, 0 = exclamation fully visible). Task 3 calls `workingOpacity(at:)` once per frame.

- [ ] **Step 1: Write the failing test**

Create `Tests/AgenticGlowAppTests/PermissionDissolveTests.swift`:

```swift
import XCTest
@testable import AgenticGlow

final class PermissionDissolveTests: XCTestCase {
    func testWorkingDwellShowsOnlyTheHexagon() {
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 0), 1)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 3), 1)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 5.99), 1)
    }

    func testPermissionDwellShowsOnlyTheExclamation() {
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 7), 0)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 8.5), 0)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 9.99), 0)
    }

    func testFadesCrossAtTheirMidpoints() {
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 6.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 10.5), 0.5, accuracy: 0.0001)
    }

    func testFadeOutFallsAndFadeInRises() {
        XCTAssertGreaterThan(
            PermissionDissolve.workingOpacity(at: 6.25),
            PermissionDissolve.workingOpacity(at: 6.75)
        )
        XCTAssertLessThan(
            PermissionDissolve.workingOpacity(at: 10.25),
            PermissionDissolve.workingOpacity(at: 10.75)
        )
    }

    func testCycleRepeatsEveryElevenSeconds() {
        XCTAssertEqual(PermissionDissolve.cycle, 11)
        XCTAssertEqual(PermissionDissolve.workingOpacity(at: 11), 1)
        XCTAssertEqual(
            PermissionDissolve.workingOpacity(at: 17.5),
            PermissionDissolve.workingOpacity(at: 6.5),
            accuracy: 0.0001
        )
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS' \
  -only-testing:AgenticGlowAppTests/PermissionDissolveTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD FAILS with "cannot find 'PermissionDissolve' in scope".

- [ ] **Step 3: Implement the timeline**

Create `Sources/AgenticGlowApp/MenuBar/PermissionDissolve.swift`:

```swift
import Foundation

/// Timeline for the combined permission + working icon: the hexagon holds,
/// dissolves into the yellow exclamation, holds, and dissolves back, on an
/// 11-second cycle. Pure math so the shape is unit-testable without AppKit.
enum PermissionDissolve {
    static let workingDwell: Double = 6
    static let fade: Double = 1
    static let permissionDwell: Double = 3
    static var cycle: Double { workingDwell + fade + permissionDwell + fade }

    /// Opacity of the working hexagon at `seconds` on the motion clock; the
    /// exclamation draws at the complement. Fades use a cosine ease so
    /// neither end of the dissolve snaps.
    static func workingOpacity(at seconds: Double) -> Double {
        let t = seconds.truncatingRemainder(dividingBy: cycle)
        if t < workingDwell { return 1 }
        if t < workingDwell + fade {
            return eased(1 - (t - workingDwell) / fade)
        }
        if t < workingDwell + fade + permissionDwell { return 0 }
        return eased((t - workingDwell - fade - permissionDwell) / fade)
    }

    private static func eased(_ linear: Double) -> Double {
        (1 - cos(.pi * linear)) / 2
    }
}
```

Note: `xcodegen generate` is only needed if the project does not pick up new files automatically; this project's `project.yml` globs sources, so run `xcodegen generate` once after creating the file.

- [ ] **Step 4: Run the test and verify it passes**

Same command as Step 2. Expected: `Test Suite 'PermissionDissolveTests' passed`, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgenticGlowApp/MenuBar/PermissionDissolve.swift Tests/AgenticGlowAppTests/PermissionDissolveTests.swift
git commit -m "feat: add permission dissolve timeline

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: StatusPresentation combined state

**Files:**
- Modify: `Sources/AgenticGlowApp/MenuBar/StatusPresentation.swift`
- Test: `Tests/AgenticGlowAppTests/StatusPresentationTests.swift`

**Interfaces:**
- Consumes: `ResolvedSessions` (unchanged; `activeProviders` already contains only thinking/usingTool providers, and `activeCount` counts permission sessions too, so working count is `activeCount - permissionCount`).
- Produces: `StatusPresentation.pulsesPermission: Bool` (true only when permission dominates, at least one session is working, and Reduce Motion is off) and `activeProviders` now also populated in that combined state. Task 3 reads both.

- [ ] **Step 1: Write the failing tests**

Add to `Tests/AgenticGlowAppTests/StatusPresentationTests.swift`:

```swift
    func testPermissionWithWorkersPulsesAndKeepsProviders() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 3,
                permissionCount: 1,
                activeProviders: [.codex, .claude]
            ),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertTrue(presentation.pulsesPermission)
        XCTAssertEqual(presentation.activeProviders, [.claude, .codex])
        XCTAssertTrue(presentation.animates)
        XCTAssertEqual(presentation.symbolName, "exclamationmark.circle.fill")
        XCTAssertEqual(
            presentation.accessibilityLabel,
            "AgenticGlow, 1 session needs permission, 2 active sessions"
        )
    }

    func testPermissionWithOneWorkerReadsSingularActiveSession() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 2,
                permissionCount: 1,
                activeProviders: [.codex]
            ),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertTrue(presentation.pulsesPermission)
        XCTAssertEqual(presentation.activeProviders, [.codex])
        XCTAssertEqual(
            presentation.accessibilityLabel,
            "AgenticGlow, 1 session needs permission, 1 active session"
        )
    }

    func testPermissionWithWorkersUnderReduceMotionStaysStatic() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 3,
                permissionCount: 1,
                activeProviders: [.codex, .claude]
            ),
            showTimer: false,
            reduceMotion: true
        )

        XCTAssertFalse(presentation.pulsesPermission)
        XCTAssertTrue(presentation.activeProviders.isEmpty)
        XCTAssertFalse(presentation.animates)
    }

    func testPermissionAloneDoesNotPulse() {
        let presentation = StatusPresentation(
            resolved: .init(
                sessions: [],
                dominantPhase: .permission,
                activeCount: 1,
                permissionCount: 1,
                activeProviders: []
            ),
            showTimer: false,
            reduceMotion: false
        )

        XCTAssertFalse(presentation.pulsesPermission)
        XCTAssertTrue(presentation.activeProviders.isEmpty)
        XCTAssertFalse(presentation.animates)
        XCTAssertEqual(
            presentation.accessibilityLabel,
            "AgenticGlow, 1 session needs permission"
        )
    }

    func testWorkingStateDoesNotPulsePermission() {
        let presentation = working(activeProviders: [.claude, .codex])
        XCTAssertFalse(presentation.pulsesPermission)
    }
```

Also fix the pre-existing fixture in `testPermissionPresentationUsesAttentionStateAndCount` so its counts are self-consistent (2 permission sessions, none working). Change `activeCount: 3` to `activeCount: 2`; the assertions stay as they are.

- [ ] **Step 2: Run the tests and verify the new ones fail**

```bash
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS' \
  -only-testing:AgenticGlowAppTests/StatusPresentationTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD FAILS with "value of type 'StatusPresentation' has no member 'pulsesPermission'".

- [ ] **Step 3: Implement the combined state**

In `Sources/AgenticGlowApp/MenuBar/StatusPresentation.swift`:

Add the stored property after `activeProviders`:

```swift
    /// True when a session awaits permission while at least one other session
    /// works and Reduce Motion is off: the controller alternates the icon
    /// between the working hexagon and the yellow exclamation.
    let pulsesPermission: Bool
```

Replace the `.permission` case with:

```swift
        case .permission:
            symbolName = "exclamationmark.circle.fill"
            title = resolved.permissionCount > 1 ? "\(resolved.permissionCount)" : ""
            let workingCount = resolved.activeCount - resolved.permissionCount
            var label = resolved.permissionCount == 1
                ? "AgenticGlow, 1 session needs permission"
                : "AgenticGlow, \(resolved.permissionCount) sessions need permission"
            if workingCount == 1 {
                label += ", 1 active session"
            } else if workingCount > 1 {
                label += ", \(workingCount) active sessions"
            }
            phaseLabel = label
            color = .systemYellow
            animates = workingCount > 0 && !reduceMotion
```

Replace the block after the switch (currently `let working = ...` through the `activeProviders =` assignment) with:

```swift
        let workingProviders = [AgentProvider.claude, .codex].filter {
            resolved.activeProviders.contains($0)
        }
        let working = [SessionPhase.thinking, .usingTool].contains(resolved.dominantPhase)
        pulsesPermission = resolved.dominantPhase == .permission
            && !workingProviders.isEmpty
            && !reduceMotion
        activeProviders = working || pulsesPermission ? workingProviders : []
```

- [ ] **Step 4: Run the tests and verify they pass**

Same command as Step 2. Expected: all StatusPresentationTests pass, including the five new ones.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgenticGlowApp/MenuBar/StatusPresentation.swift Tests/AgenticGlowAppTests/StatusPresentationTests.swift
git commit -m "feat: expose combined permission + working presentation

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Controller renders the dissolve

**Files:**
- Modify: `Sources/AgenticGlowApp/MenuBar/StatusItemController.swift`

**Interfaces:**
- Consumes: `StatusPresentation.pulsesPermission`, `StatusPresentation.activeProviders`, `PermissionDissolve.workingOpacity(at:)`.
- Produces: nothing new for later tasks; the per-frame image now composes both glyphs when dissolving.

No new unit test: this is AppKit drawing driven by already-tested inputs. Verification is the full unit suite still passing plus Task 4's visual check.

- [ ] **Step 1: Add the dissolve state flag**

In `StatusItemController`, add after `private var motionProviders: [AgentProvider]?`:

```swift
    /// True while the icon alternates between the working hexagon and the
    /// yellow permission exclamation (one session waiting, others working).
    private var dissolvesPermission = false
```

- [ ] **Step 2: Route the combined state in applyTint**

Replace the body of `applyTint(_:celebrating:)` with:

```swift
        let name = presentation.symbolName
        if celebrating {
            motionProviders = nil
            dissolvesPermission = false
            setSymbol(name, color: .systemGreen)
            return
        }
        let providers = presentation.activeProviders
        dissolvesPermission = presentation.pulsesPermission && !providers.isEmpty
        if dissolvesPermission {
            // The motion task owns the icon: hexagon spinning in provider
            // color, dissolving to and from the yellow exclamation.
            motionProviders = providers
            currentSymbolName = "circle.hexagongrid"
            currentSolidColor = ProviderColor.nsColor(for: providers[0], on: barAppearance)
        } else if providers.isEmpty {
            motionProviders = nil
            setSymbol(name, color: presentation.color)
        } else if providers.count > 1, model.reduceMotion {
            motionProviders = nil
            setSymbol(name, color: ProviderColor.bothBlend(on: barAppearance))
        } else {
            motionProviders = providers
            currentSymbolName = name
            setSymbol(name, color: ProviderColor.nsColor(for: providers[0], on: barAppearance))
        }
```

Note the dissolve branch does not call `setSymbol` (which would flash an unrotated frame); the motion task renders the next frame within 1/30s.

- [ ] **Step 3: Compose the frame in renderMotionFrame**

In `renderMotionFrame(at:)`, replace the final image assignment:

```swift
        symbolView.image = Self.symbolImage(name, color: color, rotatedDegrees: -360 * turns)
```

with:

```swift
        let rotated = -360.0 * turns
        if dissolvesPermission {
            let opacity = PermissionDissolve.workingOpacity(at: seconds)
            symbolView.image = Self.dissolveImage(
                workingName: name,
                workingColor: color,
                rotatedDegrees: rotated,
                workingOpacity: opacity
            )
        } else {
            symbolView.image = Self.symbolImage(name, color: color, rotatedDegrees: rotated)
        }
```

- [ ] **Step 4: Add the composite image function**

Add below `symbolImage(_:color:rotatedDegrees:)`:

```swift
    /// Both glyphs baked into one frame at complementary opacity. Drawing
    /// them into a single image keeps the menu bar path identical to the
    /// plain motion frames; only the pixels change.
    private static func dissolveImage(
        workingName: String,
        workingColor: NSColor,
        rotatedDegrees: Double,
        workingOpacity: Double
    ) -> NSImage? {
        guard let working = symbolImage(
            workingName,
            color: workingColor,
            rotatedDegrees: rotatedDegrees == 0 ? 0.0001 : rotatedDegrees
        ), let permission = symbolImage(
            "exclamationmark.circle.fill",
            color: .systemYellow,
            rotatedDegrees: 0
        ) else { return nil }
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            working.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: CGFloat(workingOpacity)
            )
            permission.draw(
                in: aspectFit(permission.size, in: rect),
                from: .zero,
                operation: .sourceOver,
                fraction: CGFloat(1 - workingOpacity)
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func aspectFit(_ imageSize: NSSize, in rect: NSRect) -> NSRect {
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
```

The `0.0001` degree floor forces `symbolImage` through its rotated path, which returns a pre-fit 18x18 image, so the working glyph can be drawn into the full rect. The exclamation comes back at its natural symbol size and needs the aspect-fit rect.

- [ ] **Step 5: Reset the flag on stop and celebration**

In `beginCelebrationIfNeeded`, after `motionProviders = nil`, add:

```swift
        dissolvesPermission = false
```

- [ ] **Step 6: Build and run the full unit suite**

```bash
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS' \
  -skip-testing:AgenticGlowUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all unit tests pass, no warnings in the modified files.

- [ ] **Step 7: Commit**

```bash
git add Sources/AgenticGlowApp/MenuBar/StatusItemController.swift
git commit -m "feat: dissolve menu bar icon between working and permission

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Fixture, visual verification, docs

**Files:**
- Modify: `Sources/AgenticGlowApp/UITesting/UITestSessionStore.swift`
- Modify: `gotdone.md`, `tasks/todo.md`

**Interfaces:**
- Consumes: the running app built from Tasks 1-3.
- Produces: a `permission-and-working` fixture (Claude permission + Claude thinking + Codex usingTool) launchable via `--ui-test-fixture permission-and-working`.

- [ ] **Step 1: Add the fixture**

In `UITestFixtureFactory.events(arguments:)`, add a case before `default:`:

```swift
        case "permission-and-working":
            return [
                .init(
                    schemaVersion: 1,
                    provider: .claude,
                    surface: .desktop,
                    sessionID: "mix-permission",
                    turnID: "turn",
                    phase: .permission,
                    label: "Awaiting permission",
                    toolCategory: nil,
                    projectName: "Example",
                    workingDirectory: "/tmp/Example",
                    sourceBundleID: "com.anthropic.claudefordesktop",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                ),
                .init(
                    schemaVersion: 1,
                    provider: .claude,
                    surface: .cli,
                    sessionID: "mix-claude-thinking",
                    turnID: "turn",
                    phase: .thinking,
                    label: "Thinking",
                    toolCategory: nil,
                    projectName: "horizon-app",
                    workingDirectory: "/tmp/horizon-app",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                ),
                .init(
                    schemaVersion: 1,
                    provider: .codex,
                    surface: .cli,
                    sessionID: "mix-codex-building",
                    turnID: "turn",
                    phase: .usingTool,
                    label: "Editing main.swift",
                    toolCategory: .edit,
                    projectName: "AgenticGlow",
                    workingDirectory: "/tmp/AgenticGlow",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                )
            ]
```

- [ ] **Step 2: Build Debug and launch with the fixture**

```bash
xcodebuild -project AgenticGlow.xcodeproj -scheme AgenticGlow -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
```

Then resolve the products dir with `xcodebuild -showBuildSettings` (BUILT_PRODUCTS_DIR; do not guess DerivedData paths), quit any running AgenticGlow, and launch the built app with `--ui-test-fixture permission-and-working`.

- [ ] **Step 3: Pixel-verify one full cycle**

Invoke the `review-animations` skill if installed (routed for all motion changes; if not installed, say so and continue). Then capture the icon region of the menu bar on the active display about every second for 12-13 seconds (`screencapture -x` plus crop, as in prior sessions). Expected evidence over one cycle:

- Frames 0-5s: hexagon visible, blue-dominant (or sweeping toward orange), rotating between frames.
- Around 6-7s: mixed pixels (both glyphs faintly present, no hard swap).
- Frames 7-10s: solid yellow exclamation, stationary.
- After 11s: hexagon back, still rotating (compare rotation phase against early frames to confirm the clock never restarted).

If the yellow dwell never appears or the transition hard-snaps, the feature is NOT done; debug before proceeding. Quit the fixture app afterward.

- [ ] **Step 4: Run the full test suite including UI tests (signed)**

```bash
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS'
```

Expected: all unit and UI tests pass (UI tests need real signing; do not pass CODE_SIGNING_ALLOWED=NO here).

- [ ] **Step 5: Update docs and commit**

- `tasks/todo.md`: check off this feature's plan items.
- `gotdone.md`: add an entry describing the dissolve feature and the visual evidence gathered in Step 3.

```bash
git add Sources/AgenticGlowApp/UITesting/UITestSessionStore.swift gotdone.md tasks/todo.md
git commit -m "feat: add mixed permission fixture and record dissolve verification

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Self-Review Notes

- Spec coverage: trigger conditions (Task 2), 11s dissolve cycle (Task 1), per-frame composition with clocks never pausing (Task 3), Reduce Motion fallback (Task 2 test + existing controller reduce-motion branch), accessibility label (Task 2), celebration override (Task 3 Step 5 plus existing `celebrationResetTask` guard), title unchanged (permission case keeps its title line), visual verification with a mixed fixture (Task 4). No gaps.
- Type consistency: `pulsesPermission` (Tasks 2, 3), `PermissionDissolve.workingOpacity(at:)` (Tasks 1, 3), fixture name `permission-and-working` (Task 4) used consistently.
