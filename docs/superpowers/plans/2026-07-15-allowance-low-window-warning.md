# Allowance Low-Window Warning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the menu bar's low-allowance dot is showing, opening the popover must make it obvious *which* allowance window (current and/or weekly, for either provider) caused it.

**Architecture:** Reuse the existing `AllowanceWarning.thresholdPercentLeft` constant (already the single source of truth for the menu bar badge) inside `AllowancePresentation` to compute two new boolean flags. `AllowanceSectionView` renders each window's caption as a warning `Label` instead of plain `Text` when its flag is true.

**Tech Stack:** Swift, SwiftUI, XCTest. No new dependencies.

## Global Constraints

- Low-window threshold is `AllowanceWarning.thresholdPercentLeft` (10), defined in `Sources/AgenticGlowCore/Allowance/AllowanceWarning.swift` — do not redefine or hardcode `10` anywhere else; reference the constant.
- Exactly-at-threshold (`percentLeft == 10`) is **not** low, matching the existing `AllowanceWarning.lowWindows` behavior (see `testExactThresholdIsNotLowInPresentation` in Task 1).
- Warning color is `Color(nsColor: .systemOrange)` — the same `NSColor.systemOrange` already used for the menu bar badge dot in `StatusItemController.swift:158`. Do not introduce a new color.
- Provider bar/pill coloring (`ProviderColor`) is untouched — only caption text below the bar changes.

---

### Task 1: Add low-window flags to `AllowancePresentation`

**Files:**
- Modify: `Sources/AgenticGlowApp/MenuBar/AllowancePresentation.swift`
- Test: `Tests/AgenticGlowAppTests/AllowancePresentationTests.swift`

**Interfaces:**
- Consumes: `AllowanceWarning.thresholdPercentLeft` (`Double`, public, from `AgenticGlowCore`), `ProviderAllowance.currentPercentLeft` / `.weeklyPercentLeft` (`Double?`, already existing).
- Produces: `AllowancePresentation.currentIsLow: Bool`, `AllowancePresentation.weeklyIsLow: Bool` — Task 2 reads these directly.

- [ ] **Step 1: Write the failing tests**

Add these three tests to `Tests/AgenticGlowAppTests/AllowancePresentationTests.swift`, inside the existing `AllowancePresentationTests` class (after `testClaudePreservesUsedContextWithoutReversingProgressDirection`):

```swift
    func testCurrentWindowBelowThresholdIsLowAndSpokenAloud() {
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 91,
            currentResetAt: nil,
            weeklyPercentUsed: 50,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertTrue(presentation.currentIsLow)
        XCTAssertFalse(presentation.weeklyIsLow)
        XCTAssertTrue(presentation.accessibilityCurrent.contains("low"))
        XCTAssertFalse(presentation.accessibilityWeekly!.contains("low"))
    }

    func testExactThresholdIsNotLowInPresentation() {
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 90,
            currentResetAt: nil,
            weeklyPercentUsed: 90,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertFalse(presentation.currentIsLow)
        XCTAssertFalse(presentation.weeklyIsLow)
        XCTAssertFalse(presentation.accessibilityCurrent.contains("low"))
        XCTAssertFalse(presentation.accessibilityWeekly!.contains("low"))
    }

    func testWeeklyWindowBelowThresholdIsLowIndependentlyOfCurrent() {
        let allowance = ProviderAllowance(
            provider: .codex,
            currentWindowLabel: "5h",
            currentPercentUsed: 50,
            currentResetAt: nil,
            weeklyPercentUsed: 95,
            weeklyResetAt: nil,
            fetchedAt: Date()
        )
        let presentation = AllowancePresentation(allowance: allowance, now: Date())

        XCTAssertFalse(presentation.currentIsLow)
        XCTAssertTrue(presentation.weeklyIsLow)
        XCTAssertFalse(presentation.accessibilityCurrent.contains("low"))
        XCTAssertTrue(presentation.accessibilityWeekly!.contains("low"))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AllowancePresentationTests 2>&1 | tail -40`
Expected: FAIL — `currentIsLow` / `weeklyIsLow` are not members of `AllowancePresentation`.

- [ ] **Step 3: Implement the flags and update `spoken(...)`**

In `Sources/AgenticGlowApp/MenuBar/AllowancePresentation.swift`, add two stored properties to the struct declaration (after `accessibilityWeekly`):

```swift
    let accessibilityWeekly: String?
    let currentIsLow: Bool
    let weeklyIsLow: Bool
```

In `init`, compute the flags right after `weeklyLeftPercent` is assigned (so both are available before the `currentDetail`/`weeklyValue` blocks that follow):

```swift
        weeklyLeftPercent = allowance.weeklyPercentLeft.map(Self.percent)
        weeklyUsedPercent = allowance.weeklyPercentUsed.map(Self.percent)
        weeklyResetValue = allowance.weeklyResetAt.map(Self.weeklyReset)
        currentIsLow = (allowance.currentPercentLeft ?? .infinity) < AllowanceWarning.thresholdPercentLeft
        weeklyIsLow = (allowance.weeklyPercentLeft ?? .infinity) < AllowanceWarning.thresholdPercentLeft
```

Update the `spoken(...)` calls at the bottom of `init` to pass the new flags:

```swift
        accessibilityCurrent = Self.spoken(
            provider: allowance.provider,
            window: allowance.currentWindowLabel,
            left: allowance.currentPercentLeft,
            used: allowance.currentPercentUsed,
            reset: allowance.currentResetAt,
            isLow: currentIsLow
        )
        accessibilityWeekly = allowance.weeklyPercentLeft.map {
            Self.spoken(
                provider: allowance.provider,
                window: "weekly",
                left: $0,
                used: allowance.weeklyPercentUsed,
                reset: allowance.weeklyResetAt,
                isLow: weeklyIsLow
            )
        }
```

Update the `spoken` helper itself to accept and use the new parameter:

```swift
    private static func spoken(
        provider: AgentProvider,
        window: String,
        left: Double?,
        used: Double?,
        reset: Date?,
        isLow: Bool
    ) -> String {
        var parts = [provider == .codex ? "Codex" : "Claude", window]
        if let left { parts.append("\(percent(left)) percent left") }
        if provider == .claude, let used { parts.append("\(percent(used)) percent used") }
        if let reset {
            parts.append("resets \(reset.formatted(date: .abbreviated, time: .shortened))")
        }
        if isLow { parts.append("low") }
        return parts.joined(separator: ", ")
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AllowancePresentationTests 2>&1 | tail -40`
Expected: PASS — all 5 tests in `AllowancePresentationTests` (2 existing + 3 new) green.

- [ ] **Step 5: Run the full Core+App unit suite to check for regressions**

Run: `swift test 2>&1 | tail -20`
Expected: PASS, 0 failures (same total count as before, plus 3).

- [ ] **Step 6: Commit**

```bash
git add Sources/AgenticGlowApp/MenuBar/AllowancePresentation.swift Tests/AgenticGlowAppTests/AllowancePresentationTests.swift
git commit -m "feat: add currentIsLow/weeklyIsLow flags to AllowancePresentation"
```

---

### Task 2: Render the warning in `AllowanceSectionView` and verify live

**Files:**
- Modify: `Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift`

**Interfaces:**
- Consumes: `AllowancePresentation.currentIsLow`, `.weeklyIsLow` (from Task 1).
- Produces: nothing new consumed by later tasks — this is the last task.

- [ ] **Step 1: Add a private caption helper and use it for both windows**

In `Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift`, replace the two caption call sites inside `allowanceContent(_:freshness:)`:

```swift
        let presentation = AllowancePresentation(allowance: allowance, now: Date())
        AllowanceBar(
            value: presentation.currentProgress,
            label: presentation.currentLeftPercent,
            tint: tint
        )
        .accessibilityLabel(presentation.accessibilityCurrent)
        Text(presentation.currentDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
        if let weeklyProgress = presentation.weeklyProgress {
            AllowanceBar(
                value: weeklyProgress,
                label: presentation.weeklyLeftPercent,
                tint: tint
            )
            .accessibilityLabel(presentation.accessibilityWeekly ?? "Weekly allowance")
            Text(weeklyCaption(presentation))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
```

with:

```swift
        let presentation = AllowancePresentation(allowance: allowance, now: Date())
        AllowanceBar(
            value: presentation.currentProgress,
            label: presentation.currentLeftPercent,
            tint: tint
        )
        .accessibilityLabel(presentation.accessibilityCurrent)
        allowanceCaption(presentation.currentDetail, isLow: presentation.currentIsLow)
        if let weeklyProgress = presentation.weeklyProgress {
            AllowanceBar(
                value: weeklyProgress,
                label: presentation.weeklyLeftPercent,
                tint: tint
            )
            .accessibilityLabel(presentation.accessibilityWeekly ?? "Weekly allowance")
            allowanceCaption(weeklyCaption(presentation), isLow: presentation.weeklyIsLow)
        }
```

Add the new helper method to the `ProviderAllowanceRow` struct (after `weeklyCaption(_:)`):

```swift
    @ViewBuilder
    private func allowanceCaption(_ text: String, isLow: Bool) -> some View {
        if isLow {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(nsColor: .systemOrange))
        } else {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `swift build 2>&1 | tail -30`
Expected: `Build complete!` with no errors.

- [ ] **Step 3: Run the full unit suite**

Run: `swift test 2>&1 | tail -20`
Expected: PASS, 0 failures (SwiftUI view changes have no unit test surface of their own; this confirms nothing else broke).

- [ ] **Step 4: Commit**

```bash
git add Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift
git commit -m "feat: highlight the allowance window that triggered the low-usage badge"
```

- [ ] **Step 5: Live-verify with the `signals` UI-test fixture**

The `signals` fixture already drives Codex's allowance to `currentPercentUsed: 92` (current window left = 8%, below the 10% threshold) and `weeklyPercentUsed: 95` (weekly left = 5%, also below threshold) — see `UITestAllowanceAdapter` in `Sources/AgenticGlowApp/UITesting/UITestSessionStore.swift:205-219`. Both of Codex's captions should render with the warning triangle; Claude's captions (real account data, not part of this fixture) should render plainly unless the signed-in account is also genuinely low.

Rebuild and launch, making sure no other AgenticGlow instance is running first (two same-named processes make AppleScript-driven verification land clicks on the wrong one — see `tasks/lessons.md`, "Deliberately launching a second same-named instance breaks AppleScript targeting too"):

```bash
ps aux | grep -i agenticglow | grep -v grep
```

If anything is running, quit it (production via `osascript -e 'tell application id "com.twodamax.agenticglow" to quit'`, any debug build via `pkill -f AgenticGlow.app/Contents/MacOS/AgenticGlow`), then confirm `ps aux | grep -i agenticglow | grep -v grep` is empty.

```bash
xcodebuild -project AgenticGlow.xcodeproj -scheme AgenticGlow -configuration Debug build 2>&1 | tail -15
open -n "/Users/jwright0180/Library/Developer/Xcode/DerivedData/AgenticGlow-cgwxclsyjfulpvampnwulpqlikdc/Build/Products/Debug/AgenticGlow.app" --args --ui-test-fixture signals
```

Open the popover and screenshot it (use `osascript`/System Events UI scripting as in prior sessions — `computer-use` cannot grant access to this LSUIElement app). Confirm visually:
- Codex's current-window caption ("5h · ...") shows the orange warning triangle and orange text.
- Codex's weekly caption ("Week · ...") shows the same treatment.
- The bar fill/pill colors are unchanged (still Codex blue).
- Claude's captions are unaffected (plain gray, no triangle) unless the real signed-in account happens to also be low.

Then clean up: quit the debug instance, relaunch the real app (`open -a /Applications/AgenticGlow.app`), and confirm exactly one production instance is running again.

- [ ] **Step 6: Update `gotdone.md`**

Append a dated entry to `/Volumes/Liquid/2DaMax Development/AgenticGlow/gotdone.md` describing what shipped (the low-window warning, which files changed, and the live verification screenshot outcome), following the existing entries' format in that file.

```bash
git add gotdone.md
git commit -m "docs: log allowance low-window warning ship"
```
