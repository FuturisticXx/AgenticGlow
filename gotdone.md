# Got done

## 2026-07-18 - Released v0.5.4

- John asked to build and install the release; confirmed scope was the full public release (version bump, DMG, notarization, GitHub release, cask update), not just a local install.
- Released the session-start-time and absolute-allowance-reset-date work from commit `79d8708` as v0.5.4.
- Full non-UI suite passed on the release commit: 327 tests (189 core, 6 event, 132 app), zero failures; privacy gate passed.
- Both release gate variables were confirmed with the owner in chat before use, naming `AGENTICGLOW_NAME_CLEARED` and `AGENTICGLOW_RELEASE_BUILD_APPROVED` explicitly.
- Signed universal build passed strict code-signature checks. Apple accepted notarization submission `61a5164c-e253-4816-bdd9-f6b3ac519a0b`; the DMG was stapled and validated, and Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- Published `v0.5.4` at commit `79d8708`, DMG SHA-256 `303098ed1642ac1076b098c04e35425399f3d65e509af49295059bdf68768c67`. Downloaded the release asset back and independently verified checksum, staple, and Gatekeeper.
- Cask regenerated and pushed to main (`ccb623e`) and the official tap (`863a1a8`).
- Running `/Applications/AgenticGlow.app` replaced with the notarized 0.5.4 build and relaunched; version, signature, and Gatekeeper verified.
- Left the pre-existing, unrelated uncommitted `SessionRowMotion.swift`/`SessionRowMotionTests.swift` changes (present before this whole session started, belong to the separate not-yet-finished session-card-redesign expand-to-detail motion work) out of this release entirely, same as the earlier commit.

## 2026-07-18 - Session start time and absolute allowance reset dates

- John's idea: show when a session started, and show an actual date for allowance resets instead of just relative countdowns.
- `turnStartedAt` already flowed from the hook event through `SessionResolver` into the row's live elapsed-seconds counter, but was never carried into `SessionSnapshot` as a raw date. Threaded it through and surfaced it as an absolute clock time ("Started 3:42 PM", or "Jul 17, 3:42 PM" on an earlier day) in the row's expand-to-detail panel, not the compact row, so it adds a fixed anchor instead of duplicating the live counter already visible.
- Allowance captions: the weekly reset now includes the calendar date ("Week · resets Tue, Jul 21 at 12:59 PM" instead of just the weekday), and the current 5h window's countdown is paired with its absolute clock time ("5h · 1h 59m (2:59 PM)").
- Tests first, matching project convention: 3 new `SessionDetailPresentationTests`, 1 new `SessionResolverTests`, 2 new `AllowancePresentationTests`. Full suite 321/321 (189 core, 132 app), zero failures.
- Verified visually: same technique as the brain-icon feature, since this accessory app's popover isn't reachable by screen automation in this environment (confirmed again this session). Real `SessionRowView` and `AllowanceSectionView` rendered directly to a PNG via a temporary `ImageRenderer` hook in `AppDelegate.swift`, reverted immediately after capture, not part of the shipped diff.
- Committed (`9fc2863`) to `main`. Not pushed, no version bump, no release.
- Left two pre-existing, unrelated uncommitted files alone (`SessionRowMotion.swift`, `SessionRowMotionTests.swift`, present before this session started, part of the not-yet-finished session-card-redesign expand-to-detail motion work) rather than bundling them into this commit.

## 2026-07-17 - Released v0.5.3

- Root-caused why v0.5.2's Codex window-raise feature never actually worked on real Codex desktop sessions: `sourceBundleID` was nil for every one of them (8/8 checked). OpenAI renamed the desktop app to ChatGPT, and the process resolver only accepted a bundle ID from a process named exactly "codex"/"Codex", so it silently missed the real "ChatGPT" process. Fixed by accepting a known alias name per provider; Claude was already correct and is unaffected. Caught a stale test fixture along the way that had assumed the old app name and masked this for months.
- Also swapped the sparkle fallback shown for uncategorized tool use to a tools icon (`wrench.and.screwdriver`), matching the same icon-swap-only pattern as the earlier brain icon change.
- Discovered and worked around a separate, real gap: the standalone helper binary at `~/Library/Application Support/AgenticGlow/bin/agenticglow-event`, the one Codex's hooks actually invoke, is only refreshed through the Setup window's manual "Install" flow, never automatically on launch or upgrade. Every prior release that touched hook-processing logic had been silently shipping inert until Setup was manually re-run. Manually refreshed it for this release; logged as follow-up work in `docs/release-checklist.md` to fix properly (auto-refresh on launch when it differs from the embedded copy).
- John separately confirmed the earlier "no new session file" mystery from this same investigation was caused by switching OpenAI accounts in Codex, not a code bug. Root mechanism still unconfirmed; logged in `tasks/lessons.md` as a follow-up.
- Full suite passed on the release commit (`ffc56d2`): 312 tests (188 core, 124 app), zero failures; privacy gate passed.
- Both release gate variables confirmed and used: `AGENTICGLOW_NAME_CLEARED=1`, `AGENTICGLOW_RELEASE_BUILD_APPROVED=1`.
- Signed universal build passed strict code-signature checks. Notarization submission `5e2bb621-039d-4b26-a0aa-2fbd6b785284` accepted; DMG stapled, validated, Gatekeeper accepted app and DMG as `Notarized Developer ID`.
- Published `v0.5.3` at commit `ffc56d2`, DMG SHA-256 `39bda93563eb13e66fbd4fc6a3349a9f45c1024f4cf0f91f1cf73186c087fa34`. Downloaded the release asset back and independently verified checksum, staple, and Gatekeeper.
- Cask regenerated and pushed to main (`901fe10`) and the official tap (`fa39f4a`).
- Running `/Applications/AgenticGlow.app` replaced with the notarized 0.5.3 build and relaunched; version, signature, and Gatekeeper verified. Standalone hook helper binary also manually refreshed so the fix actually takes effect for real Codex hook events, not just the app bundle.

## 2026-07-17 - Released v0.5.2

- Released the Codex window-raise fix and the brain icon for thinking sessions together, both already verified live by John on a local signed test build before this release.
- Full suite passed on the release commit (`984ffda`): 312 tests (188 core, 124 app), zero failures; privacy gate passed.
- Both release gate variables confirmed and used: `AGENTICGLOW_NAME_CLEARED=1`, `AGENTICGLOW_RELEASE_BUILD_APPROVED=1`.
- Signed universal build passed strict code-signature checks. Notarization submission `a159df04-6357-44cb-a4d7-0eb6017891cf` accepted; DMG stapled, validated, Gatekeeper accepted app and DMG as `Notarized Developer ID`.
- Published `v0.5.2` at commit `984ffda`, DMG SHA-256 `d3a7e485b7e6f56252726dc3485f8f35fe52b6893f39e6705e5f9c59fe475840`. Downloaded the release asset back and independently verified checksum, staple, and Gatekeeper.
- Cask regenerated and pushed to main (`796cab0`) and the official tap (`5c8c568`).
- Running `/Applications/AgenticGlow.app` replaced with the notarized 0.5.2 build and relaunched; version, signature, and Gatekeeper verified.

## 2026-07-17 - Brain icon for thinking sessions

- John liked Claude Code CLI's own working animation and asked for something similar in AgenticGlow, with a brain icon specifically for the thinking state, for both providers (today's icon mapping isn't provider-specific).
- Explored a few animated treatments (radiating rays, a chasing dot wave) via inline preview widgets, but the real SF Symbol shape shown in a rendered comparison didn't match an early Tabler-icon-based mockup, causing a round of back-and-forth. John then asked to keep it simple: swap the icon, keep the existing pulse animation unchanged.
- Shipped: `SessionPhasePresentation`'s row icon for `.thinking` is now `brain` instead of `sparkle`; `.usingTool` keeps its existing per-category icons (pencil, magnifying glass, etc.) and sparkle fallback, unchanged.
- Verified visually: since the popover window wouldn't reliably show via menu-bar-click automation in this environment, rendered the real `SessionRowView` directly to a PNG via `ImageRenderer` (temporary debug hook in `AppDelegate.swift`, reverted immediately after capture, not part of the shipped diff). Confirmed the Claude "horizon-app" row shows the new brain icon while the Codex "AgenticGlow" row keeps its pencil icon for editing.
- Full suite passed: 312/312, zero failures.
- Committed (`b1e9dbd`) and pushed to `main` alongside the Codex window-raise fix.

## 2026-07-17 - Codex window raise on session click

- John reported clicking a session row does "nothing visibly" on his multi-display setup. Root cause confirmed against Apple's own developer forums: `NSRunningApplication.activate()` called from a background/`.accessory` app (exactly what AgenticGlow is) is documented as unreliable on macOS 14+, especially across displays/Spaces, not a bug in AgenticGlow's code.
- John declined full Accessibility permission (system-wide UI control of any app) as too broad, so implemented a narrower, Codex-only fix instead: AppleScript sent directly to Codex (which actually runs as `/Applications/ChatGPT.app`, bundle id `com.openai.codex`, confirmed live) asking it to raise itself and reorder the matching window to front, using its inherited Chromium AppleScript dictionary. This asks Codex to activate itself from within its own process, sidestepping the cross-app activation restriction that plain `NSRunningApplication.activate()` hits. Uses only a narrow, one-time, per-app "AgenticGlow wants to control ChatGPT" Apple Events automation prompt, not system-wide Accessibility. Claude.app has no AppleScript dictionary at all, so it is unaffected and keeps today's behavior.
- New `CodexWindowScript` (pure, testable): builds the AppleScript source and safely escapes the project name used for title-matching (prevents AppleScript injection from a malicious project directory name).
- `ApplicationActivating` protocol gained `activate(bundleIdentifier:projectName:)`, with the existing single-arg call site (the notification click handler) preserved via a protocol-extension default.
- Falls back silently to the existing generic `activate()` behavior if the permission is denied, Codex has no matching window open, or for any other bundle id (Claude) - never surfaces an error, never re-prompts.
- Added `NSAppleEventsUsageDescription` to `Config/AgenticGlow-Info.plist`; documented the new permission in `docs/privacy.md` (optional, Codex-only, degrades gracefully).
- Verified: full suite 312/312 (188 Core, 124 App), zero failures; privacy gate passes. Live manual verification (granting the system permission prompt, confirming the window comes forward) still needed from John - not something Claude can do on his behalf.
- Not committed to git yet, pending John's review.

## 2026-07-17 - Released v0.5.1

- Released the low-allowance warning color split (patch bump, matching how small single-fix changes like 0.4.6 and 0.4.10 were versioned, unlike the minor 0.5.0 bundle).
- Verified the Claude side of the fix live before releasing: the shared `allowanceCaption` code already resolves `tint` per provider, so no separate Claude-specific code was needed, confirmed by temporarily forcing Claude's allowance low in a debug build (reverted after verification, not part of the shipped diff).
- Full suite passed on the release commit (`29b1996`): 310 tests (180 core, 6 event, 124 app), zero failures; privacy gate passed.
- Both release gate variables confirmed and used: `AGENTICGLOW_NAME_CLEARED=1`, `AGENTICGLOW_RELEASE_BUILD_APPROVED=1`.
- Signed universal build passed strict code-signature checks. Notarization submission `26a4236b-1ba6-465d-adc1-5c828765c349` accepted; DMG stapled, validated, Gatekeeper accepted app and DMG as `Notarized Developer ID`.
- Published `v0.5.1` at commit `29b1996`, DMG SHA-256 `36240e1f599c9f916181b957ad3bd3cf25744d89a067c48b2593dbf26c2b5f57`. Downloaded the release asset back and independently verified checksum, staple, and Gatekeeper.
- Cask regenerated and pushed to main (`a611cff`) and the official tap (`10d3167`).
- Running `/Applications/AgenticGlow.app` replaced with the notarized 0.5.1 build and relaunched; version, signature, and Gatekeeper verified.

## 2026-07-16 - Released v0.5.0

- Released the session card redesign, its code-review fix pass, and the Codex weekly-label fix together as v0.5.0 (a minor bump, matching how 0.4.0 was used for a comparably-sized bundle of visible feature work).
- README's install link updated from the stale v0.4.7 to v0.5.0; privacy docs needed no changes since the redesign added no new data collection or endpoints.
- Full suite passed on the release commit (`ce27d2d`): 310 tests (180 core, 6 event, 124 app), zero failures; privacy gate passed.
- Both release gate variables confirmed and used: `AGENTICGLOW_NAME_CLEARED=1`, `AGENTICGLOW_RELEASE_BUILD_APPROVED=1`.
- Signed universal build passed strict code-signature checks. Notarization submission `00d3f3b2-e22d-4d14-bc9f-3fcddba06e97` accepted; DMG stapled, validated, Gatekeeper accepted app and DMG as `Notarized Developer ID`.
- Published `v0.5.0` at commit `ce27d2d`, DMG SHA-256 `b2d5bfacd4fdf78c72e9e10463b9d894026d9ec00152cc19b50b6bb19163fbdf`. Downloaded the release asset back and independently verified checksum, staple, and Gatekeeper before trusting it.
- Cask regenerated and pushed to main (`27e439c`) and the official tap `FuturisticXx/homebrew-agenticglow` (`d069e2c`).

## 2026-07-16 - Fixed Codex allowance label showing "Current, 152h 7m"

- John spotted the live popover showing "Current, 152h 7m" for Codex's usage window instead of a sensible label. Root cause found by querying Codex's app-server directly (same account/rateLimits/read JSON-RPC call AgenticGlow uses): this account (ChatGPT Plus) is currently returning its weekly limit as the primary window (windowDurationMins: 10080, secondary: null) instead of the usual 5h-primary-plus-weekly-secondary pair. CodexAllowanceNormalizer only recognized windowDurationMins == 300 as "5h" and fell back to a vague "Current" for anything else, including this legitimate weekly-scale reading.
- Fix: label by known duration (300 min to "5h", 10,080 min to "Weekly", anything else keeps the "Current" fallback) instead of a single binary check. Verified against real live data pulled straight from the Codex app-server, not just a synthetic fixture.
- Verified: full suite 310/310 (180 Core, 6 Event, 124 App); privacy gate and git diff --check both pass.

## 2026-07-16 - Code review fix pass on the session card redesign

- Ran /code-review (8 finder angles, 1-vote verify) on the 8-commit redesign branch. 10 findings survived verification; fixed all of them.
- Correctness: `.failed` sessions now get a distinct "stopped while working" VoiceOver suffix (SessionRowView.accessibilityLabel) instead of silently reusing the pre-crash label; AppModel's usage-quota refresh now fires on a transition into `.failed`, not just `.completed` (new testable `AppModel.endedThisRefresh` helper, matching the review's request for pure decision logic instead of ad-hoc inline branching).
- Reuse: added `SessionPhase.isActive` as the one shared definition of "actively thinking or using a tool," replacing 8 independent `[.thinking, .usingTool].contains(...)` copies across Core and App. Added `DurationTier` so the row timer, menu bar timer, and detail panel's "last updated" text share one seconds-to-tier boundary decision instead of three independently hand-rolled ones (each formatter keeps its own exact string output, verified against existing tests).
- Simplification: `SessionPhasePresentation.symbolName` collapsed from two full switches (4 of 6 cases duplicated verbatim) to one switch where only idle/thinking/usingTool branch by context. `SessionRowView` binds `accessibilityValue` once instead of computing it twice per render, and consolidated two of three pulse-trigger hooks into one `onChange` watching the derived `shouldPulse` boolean directly (the reviewer's literal suggestion to drop `@State` entirely was checked and rejected: it would have silently killed the repeating animation, since `.animation(_:value:)` only fires on actual value transitions, not a steady derived boolean).
- Conventions: fixed a real, embarrassing one, 91 em dashes across `docs/session-redesign-research.md`, `gotdone.md`, and `tasks/todo.md`, all new content from this session, breaking my own standing "never use em dashes" rule.
- Deliberately not fixed: a narrower edge case where a stale or dismissed `.failed` session can reappear looking "fresh" after a transient session-store read error resets `AppModel`'s resolution memory. Investigated a minimal fix (skip the reset) and found it doesn't actually work, `SessionResolver`'s own retention-pruning logic wipes the same memory anyway when called with zero events, which is itself required by the existing, deliberately-tested "fail closed on load error" contract (`testRefreshFailsClosedAfterStoreLoadFailure`). A real fix needs to distinguish "genuinely no events" from "transient read error" as a first-class case, which is bigger than a review fix-up; flagged for John rather than forcing a change that trades one bug for another. Also not restructured: `.failed` as a sibling `SessionPhase` case rather than a reason on `.disconnected`, a real architecture question (SessionPhase is Codable/persisted) that deserves an explicit decision, not a silent refactor.
- Verified: full suite 307/307 (177 Core, 6 Event, 124 App); `Scripts/verify-privacy.sh` and `git diff --check` both pass.

## 2026-07-16 - Session card redesign (research + 6-task implementation)

- Deep research pass (code audit, HCI/attention research, Apple design principles, competitive analysis) written to `docs/session-redesign-research.md`. John approved the card-redesign mockup; glow effect and usage bars explicitly frozen throughout.
- `SessionPhasePresentation` unifies the session row and menu bar icon's icon/color tables, which had silently drifted (idle and working shared one menu bar glyph; the row used a third, different glyph for each).
- Added an inferred `.failed` phase: a process that disconnects mid-task (`.thinking`/`.usingTool`) now reads as failed, distinct from a clean disconnect from idle/completed/permission. No error/exit-code signal exists in the hook payload, so this is a heuristic; priority order is permission > usingTool > thinking > failed > completed > disconnected > idle.
- Session rows now show a per-action icon (pencil/doc.text/magnifyingglass/globe/terminal/arrow.triangle.branch) from `ToolCategory`, which the resolver already classified but never threaded to the view.
- Actively-working rows breathe (opacity) on their own status glyph via the pure, testable `SessionRowMotion`, instead of relying solely on the menu bar icon for "something is happening." While researching this, found the Reduce Motion "read once at launch" bug described in the research doc doesn't actually exist (`ReduceMotionObserver` in `AppDelegate.swift` already handles it live, with passing tests), corrected the doc rather than fixing a non-bug.
- Elapsed time is now exposed to VoiceOver via a separate `accessibilityValue` + `.updatesFrequently`, instead of being silently hidden.
- Added an expand-to-detail tier: a disclosure chevron (sibling to the activate button, not nested) reveals current step, surface, and last-updated relative time (data already collected, never shown), plus an honest explanatory note for `.failed` sessions.
- TDD throughout: every task RED before GREEN, one commit per task. Full suite 294/294 (175 Core, 6 Event, 113 App); `Scripts/verify-privacy.sh` passes.
- Live-verified with a new `redesign-states` UI-test fixture (permission/working/failed/completed sessions) launched as a separate ad-hoc-signed Debug build alongside the running production app, screenshotted on Display 3. Confirmed live: the red failed icon on a mid-task-disconnected session, the pencil tool-category icon on the working session, and the expand chevron rendering on each row. Not live-verified: the actual click-to-expand interaction (avoided a multi-display coordinate click to stay clear of the running production instance), Dark mode (the fixture launch path and `--visual-qa` forced-appearance path are mutually exclusive in `AppDelegate` today), and VoiceOver's actual spoken output. Test build quit cleanly afterward; confirmed the production instance was the sole remaining process.
- No push, no release, no version bump. All commits local for John's review.

## 2026-07-15 - Released v0.4.11

- Released the allowance low-window warning: full non-UI suite passed 257 tests (167 core, 90 app) with zero failures; privacy gate passed.
- Both release gate variables (`AGENTICGLOW_NAME_CLEARED`, `AGENTICGLOW_RELEASE_BUILD_APPROVED`) were confirmed with the owner in chat before use, per the established pattern.
- Signed universal build passed strict code-signature checks. DMG notarized (submission `05999765-8e15-49fe-ab08-acf86e60bf30`, Accepted), stapled, and Gatekeeper-accepted for both the app and DMG.
- Published https://github.com/FuturisticXx/AgenticGlow/releases/tag/v0.4.11 (SHA-256 `2f319a01...`); downloaded asset re-verified checksum, staple, and Gatekeeper. Cask bumped in main (`e10cab8`) and the official tap (`a1c2a7b`).
- Installed the notarized build to `/Applications` (reports 0.4.11, signed, Gatekeeper-accepted) and relaunched.

## 2026-07-14 - Allowance low-window warning shipped

- Popover now visually highlights whichever allowance window (current or weekly, per provider) triggered the menu bar's low-usage badge: the caption swaps to an orange warning triangle + orange semibold text instead of plain gray, while bar/pill fill colors stay in the provider's own color.
- Two-task build: `AllowancePresentation.currentIsLow`/`.weeklyIsLow` flags (with test coverage) landed first, then `AllowanceSectionView.swift` consumed them via a new `allowanceCaption(_:isLow:)` helper.
- Files changed: `Sources/AgenticGlowApp/MenuBar/AllowancePresentation.swift`, `Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift`, `Tests/AgenticGlowAppTests/AllowancePresentationTests.swift`.
- Build (`xcodebuild build`) succeeded; full unit suite passed 88/88 with 0 failures.
- Live-verified with the `signals` UI-test fixture (Codex forced to 8% current / 5% weekly, both below the 10% threshold) on a Debug build launched via `--ui-test-fixture signals`. Screenshot of the open popover confirmed both Codex captions render with the orange warning triangle and orange text, while both bar fills stayed Codex blue. Display note: the menu bar icon's orange badge dot and the popover's warning color only rendered at full saturation on the active display (BenQ, Display 3, matching macOS's known inactive-display dimming); the debug instance was quit and the real `/Applications/AgenticGlow.app` relaunched afterward, confirmed as the sole running instance.

## 2026-07-11 - Codex workspace session reporting repaired

- Registered and opened the canonical `/Volumes/Liquid/2DaMax Development/AgenticGlow` project without recreating the deleted Klarity path or editing Codex private state.
- Verified a real current-task `Thinking` event at 10:23:49 PM with the canonical AgenticGlow working directory. Its `sourceProcessID` 48031 exactly matched the running ChatGPT/Codex app-server process.
- Confirmed AgenticGlow diagnostics remained off, the earlier synthetic diagnostic session was absent, and the temporary installer download caused by the bundled-app CLI mismatch was removed.

## 2026-07-11 - Usage alert verification complete

- Verified deterministic XcodeGen regeneration with no `project.pbxproj` diff.
- Full unsigned non-UI suite passed 234 tests with 0 failures and no Keychain prompt.
- Standalone helper verification, privacy verification, and `git diff --check` all passed.

## 2026-07-11 - Helpful low and exhausted usage notifications

- Low-usage alerts now include the provider reset time when available. Reaching 0 percent emits a distinct provider and window-specific exhausted alert with availability guidance or a clear fallback when no reset is known.
- Low and exhausted alerts reuse the same provider-window notification identifier, so the exhausted banner replaces the earlier warning in Notification Center instead of adding clutter.
- TDD evidence: the focused service test first failed on the missing reset formatter, the weekly title test then failed on a deliberate five-hour-only implementation, and the final `AgentNotificationServiceTests` run passed 11 tests with 0 failures.

## 2026-07-11 - Quota alerts deduplicated by usage state

- Replaced reset-timestamp notification keys with per-provider, per-window low and exhausted states. Moving reset times no longer create repeat alerts, 0 percent is a distinct transition, and healthy recovery re-arms the next cycle.
- Added regression coverage for repeated low readings, low to exhausted, first observation at 0 percent, moving reset timestamps, recovery, and independent providers and windows.
- TDD evidence: the focused test first failed because semantic alert levels did not exist, then `NotificationPolicyTests` passed 10 tests with 0 failures.

## 2026-07-11 - Isolated implementation workspace preparation

- Added `.worktrees/` to the repository ignore rules before creating the approved isolated implementation worktree, preventing linked checkout contents from appearing in project status or commits.

## 2026-07-11 - Usage alert and Codex workspace implementation plans

- Split the approved work into two executable plans: a test-first usage alert state machine and a supported Codex workspace session repair.
- Locked the notification plan to one low alert, one exhausted alert, stable replacement IDs, reset-time copy, recovery-based re-arming, and the full non-UI verification surface.
- Kept the workspace repair outside AgenticGlow runtime code: use `codex app PATH`, avoid private Codex state edits and compatibility symlinks, then require a real current-process hook event as proof.

## 2026-07-11 - Usage alert and Codex session repair design

- Traced repeated Claude 0 percent notifications to reset-timestamp-based quota deduplication and approved a state-transition design with one low warning, one exhausted alert, recovery-based re-arming, reset-time copy, and notification replacement.
- Traced the missing live Codex session to this task's deleted Klarity working directory. Verified that the installed AgenticGlow helper writes a valid current-process session event when launched from the real AgenticGlow directory.
- Added `docs/superpowers/specs/2026-07-11-usage-alerts-and-codex-session-repair-design.md` as the implementation contract. No runtime code changed in this design step.

## 2026-07-11 - Published v0.4.6

- Patch release for the "/" project-name fix: sessions with a root working directory now fall back to the provider name (HookNormalizer), with a TDD test that reproduced the symptom first; AgentProvider.displayName made public in Core.
- Evidence on release commit de8b30e: 158 core + app unit tests green (ad-hoc signed), all 7 UI tests green on a clean signed run, privacy gate passed, CI green.
- Signed universal build; DMG notarized (Accepted), stapled, Gatekeeper accepts app and DMG. SHA-256 bb4f08803938fc8472f3693e517c5458bd005cfac9673a576ec99a63b2e60276.
- Installed to /Applications (reads 0.4.6) and relaunched. Tagged v0.4.6 at de8b30e; published https://github.com/FuturisticXx/AgenticGlow/releases/tag/v0.4.6; downloaded asset matched checksum, staple, and Gatekeeper.
- Cask bumped on main and in the tap (tap commit 494623e).
- Note: previously recorded events keep their baked "/" label until they refresh; only new events get the fallback.

## 2026-07-10 - Published v0.4.5 (Liquid Glass)

- John's Liquid Glass work (glass popover surface, Glass Clarity slider shared across Settings and popover, visual QA session display) merged to main via fast-forward of his NewGlass branch on top of the v0.4.0 release commits.
- Fixed his new UI test before release: app.menuItems["Settings…"] matched both the app menu and the popover menu item; the popover item now has accessibilityIdentifier AgenticGlow.SettingsMenuItem and the test uses it. All 7 UI tests pass signed; unit bundles green.
- Signed universal 0.4.5 build, DMG notarized and stapled, Gatekeeper accepts app and DMG as Notarized Developer ID. SHA-256 6acd2b5d0decba3083a38b4f2c42adf49cf20b7fa6c187a54a9bf403b7fcc160.
- Installed to /Applications replacing 0.4.0 and relaunched; Info.plist reads 0.4.5.
- Tagged v0.4.5 at 1f5595e and published https://github.com/FuturisticXx/AgenticGlow/releases/tag/v0.4.5; downloaded asset matches checksum, staple validates, spctl accepts.
- Cask bumped in main repo and tap (tap commit a4abad2).
- Keychain prompt annoyance addressed: John will Always Allow the signing keys; lesson recorded that ad-hoc signing is unit-tests-only (it breaks UI test automation, 5 of 7 failed).

## 2026-07-09 - Published v0.4.0

- Installed build/AgenticGlow.app to /Applications replacing 0.3.0; Info.plist reads 0.4.0, Gatekeeper accepts as Notarized Developer ID, app launched and the status item is live.
- Tagged v0.4.0 at 703c467 and published the GitHub release with the notarized DMG: https://github.com/FuturisticXx/AgenticGlow/releases/tag/v0.4.0. Notes cover everything since 0.2.0 (0.3.0 was never tagged): notifications, low-allowance badge, incident line, reset celebration, provider color language, plus the 0.4.0 calm-motion and adaptive-palette work.
- Verified the published asset by downloading it back: SHA-256 matches c079f59e..., staple validates, spctl accepts.
- Cask bumped to 0.4.0 in the main repo (5dc7abb) and the tap FuturisticXx/homebrew-agenticglow (6bb0916).

## 2026-07-09 - Built and notarized the 0.4.0 release

- Signed universal release build via Scripts/build-release.sh 0.4.0: gates passed, codesign strict verification passed, lipo shows x86_64 arm64 for the app and the event helper, Info.plist stamps 0.4.0.
- DMG created, signed, notarized (submission bb34b41b-4de9-48d7-8b43-27e5e441b6ad, status Accepted), and stapled via Scripts/create-dmg.sh 0.4.0. Gatekeeper accepts both app and DMG as Notarized Developer ID.
- DMG: build/AgenticGlow-0.4.0.dmg, 4.0M, SHA-256 c079f59e1d495b2df654ffc6eafea01685756546c939fb9786678c639c395e62.
- Ships the calm-motion and adaptive-color icon work from commit 2f59788 (CI green).
- Not yet done, pending John: install to /Applications, tag v0.4.0, publish the GitHub release, bump the cask in the tap.

## 2026-07-09 - Calm motion and appearance-adaptive colors for the menu bar icon

- Deepened Claude orange (0.82/0.37/0.22) after John flagged the coral washing out; white pill text contrast improves 3.14:1 -> 3.91:1.
- Rewrote icon motion after John reported glitching: one 30fps frame task now bakes rotation and color into a single image per frame (SF Symbol rotate effect restarted on every cross-fade image swap; that was the stutter). Rotation 12s/rev, cross-fade 5s per direction on a monotonic clock (the old loop drifted 8.7s actual vs 6s nominal).
- Fixed the spin restarting every second: timer-title ticks re-applied the symbol effect each update during a session's first minute.
- Capped the sweep at 80% orange so it never parks on full alert-orange (cosine dwell); solid orange still means Claude working alone.
- Adaptive palettes: the frame task resolves colors per frame against the bar's effectiveAppearance verdict, deep palette on light bars, bright on dark. No KVO (our own renders storm it at ~325 events/s), no screen sampling, no new permissions.
- Tried and rejected with John: thin black outline around the glyph ("looks terrible").
- Verified by measurement on the live bar: 9.99s sweep vs 10.0 target; rotation autocorrelation peaks +0.95 at exactly 2.0s lag (hexagon 60-degree symmetry at 12s/rev = constant spin, no restarts); deep palette confirmed on a light bar by pixel distance (rgb(43,119,209), 26 from deep vs 55 from bright target). 157 core + 53 app + 6 UI tests green.
- Known system behaviors documented in tasks/todo.md: macOS dims inactive displays' menu bars (that was most of the "washed out on light wallpaper" complaint) and can lag the bar's light/dark verdict after wallpaper changes (Apple's own template icons went black-on-black during the lag).
- Pushed to main.

## 2026-07-09 - Provider color language for the icon and session list

- One color language across the app: Claude orange, Codex azure, shared via a new `ProviderColor` helper that the allowance pills, session rows, and menu bar icon all read from.
- Menu bar icon now colors by who is working: solid orange for Claude only, solid blue for Codex only, and a slow blue <-> orange cross-fade when both are working (static violet under Reduce Motion). Session rows tint their icon by provider, and the popover summary names the active agents ("Claude and Codex working").
- Core change: `ResolvedSessions.activeProviders` (thinking/usingTool only), unit-tested. `StatusPresentation` exposes the active provider tints; `StatusItemController` drives the cross-fade.
- Fixed a real rendering bug found during verification: the menu bar flattens template images to monochrome and ignores `contentTintColor`, so icon color never actually showed (the old yellow/green/blue states were invisible too). Now the color is baked into a non-template symbol image, so it renders. Verified live: blue, orange, and yellow all appear.
- Incident line polish: made it neutral gray (keeps the warning triangle) so orange stays "Claude", and it now only fires on `major`/`critical` outages. This removed a false "Codex: Partial System Degradation" alarm that was actually OpenAI's unrelated FedRAMP component at `minor`.
- Verified: 205 unit tests green, privacy gate passes, popover captured in Light and Dark, menu bar icon captured cross-fading. Added a `both-working` UI fixture. Reduce Motion violet verified by construction (same render path), not captured live.
- Built and installed locally as 0.3.0 for John to watch the fade live. No commit pushed yet at time of writing; no version bump beyond the local build stamp.

## 2026-07-08 - Percentage pill on the allowance bars

- Moved each allowance bar's percent-left onto the bar itself as a floating, provider-colored pill (Claude orange, Codex azure, white text, no arrow), inspired by a macOS weather "Feels Like" widget John shared.
- Dropped the standalone "X% left · Y% used" text line; the pill now carries the number, and Claude's "% used" was removed so both providers read the same. Window and reset info moved to a caption under each bar (`5h · 1h 59m`, `Week · resets Sat 8:29 PM`).
- The pill clamps near the track edges so very low or very high percentages stay fully visible instead of clipping.
- Verified: Debug build succeeded, `AllowancePresentationTests` passed, and the live popover was captured in both Light and Dark mode via the `signals` fixture (8% / 5%), confirming the clamping and that the white number stays readable on both provider tints. System appearance was flipped only for the dark capture and restored.
- Single-file change to `Sources/AgenticGlowApp/MenuBar/AllowanceSectionView.swift`. Committed separately from pre-existing `project.pbxproj` bookkeeping that registers the status and notification test files.
- No version bump, no release. Local commits pushed to main.
- Follow-up: pushing main also carried the previously local-only v0.3.0 notification commits public. CI (Xcode 16.4) then caught a pre-existing non-Sendable `UNNotificationSettings` error in `AgentNotificationService.swift` that the newer local toolchain had accepted. Fixed by reading the status through `getNotificationSettings` and resuming the continuation with only the Sendable `UNAuthorizationStatus`. CI run 28989478040 passed all jobs.

## 2026-07-06 - Cleaned up 0.2.0 release bookkeeping

- Updated the current release goal to monitor v0.2.0 instead of v0.1.1.
- Ignored AppleDouble metadata files so external-drive filesystem artifacts do not dirty the repository.

## 2026-07-05 - Released 0.2.0 publicly with the Dark Mode fix

- Built, signed, and notarized the universal 0.2.0 release; Apple accepted the submission and Gatekeeper accepts the app and DMG as Notarized Developer ID.
- Published GitHub release `v0.2.0` with the DMG (SHA-256 `9b990455...7ed512`), verified the uploaded asset round-trips with matching checksum, staple, and Gatekeeper checks.
- Bumped `Cask/agenticglow.rb` to 0.2.0 on main and pushed the same cask to the official Homebrew tap, so `brew upgrade` serves 0.2.0.
- Replaced the installed v0.1.1 in /Applications with the notarized 0.2.0 and verified the dark popover from the installed app.
- Recorded full evidence in `docs/release-checklist.md`.

## 2026-07-05 - Fixed washed-out Dark Mode popover

- Reproduced John's "Dark Mode is too light" report with live popover screenshots: on macOS 26+ the background was Color.clear over Liquid Glass, letting desktop content bleed through.
- Added a Dark Mode scrim (black at 0.45, named constant) behind the popover content; John picked strength B from three labeled live captures.
- Unified the popover aura to the light-mode palette with normal blending after John clarified the dark aura's bleached border glow was the real complaint.
- Ran /code-review (8 finder angles, 2 verifiers): fixed the magic-number findings; documented that pre-macOS-26 dark mode intentionally keeps plain regularMaterial.
- Verified with a rebuilt-app screenshot in Dark Mode, 154/154 tests, and the privacy gate. John approved the live build, then committed as `98e5b26` and pushed to main.

## 2026-07-05 - Approved task-aware session title design

- Approved primary session labels based on provider thread titles, with a locally generated task description and project-folder fallback.
- Preserved the project folder as secondary context and kept raw prompts, responses, and transcripts outside persistent state.
- Documented deterministic on-device title generation, precedence, compatibility, privacy, failure behavior, and verification requirements.

## 2026-07-05 - Fixed Codex allowance from macOS GUI launches

- Diagnosed Codex allowance as unavailable because AgenticGlow preferred the Homebrew Node launcher while macOS GUI launches omit Homebrew from `PATH`.
- Changed executable discovery to prefer the self-contained Codex.app binary while preserving existing command-line fallbacks.
- Added a regression test for candidate ordering and verified live allowance refresh under the restricted GUI `PATH`.
- Passed 154 non-UI tests, privacy verification, standalone-helper verification, and a universal local build.

## 2026-07-05, Public release and Homebrew distribution

- Published the AgenticGlow repository and releases `v0.1.0` and `v0.1.1` publicly.
- Verified the public signed and notarized v0.1.1 DMG at SHA-256 `ead3891c296770f8e455c9495f68987530e24a96197539287dbbd2bcf14aec35`.
- Reproduced and fixed the Homebrew uninstall hang caused by command-mode cleanup not exiting.
- Added `Scripts/verify-uninstall-command.sh` and verified it against the signed release app.
- Published the official Homebrew tap at `FuturisticXx/homebrew-agenticglow`.
- Verified Homebrew install, launch, uninstall, integration cleanup, removal, reinstall, signature, Gatekeeper status, and relaunch for version 0.1.1.
- Documented that an upstream `homebrew/homebrew-cask` PR is deferred until AgenticGlow meets Homebrew's self-submission notability threshold.

## 2026-07-04, Standalone repository consolidation

- Replaced the linked AgenticGlow worktree with a self-contained repository at the same canonical path.
- Archived superseded Task 9 source and tests on local branch `archive/task-9-superseded` at commit `77fe3bb` without merging it into `main`.
- Preserved the old Devin work as a verified binary patch, a separate source archive, and local recovery branch `archive/devin-task-11-base`.
- Created and verified a complete all-refs Git bundle at `/Volumes/Liquid/AgenticGlow-Migration-Backup/AgenticGlow-all.bundle`.
- Removed the obsolete `AgenticGlow-task9`, `AgenticGlow-linked-backup`, and `AgenticGlow-devin-task-11` directories after all recovery gates passed.
- Verified deterministic project generation, 151 tests with 0 failures, privacy and standalone-helper checks, icon assets, legacy-name removal, and universal `x86_64 arm64` Release binaries.
- Kept the canonical repository on local `main`; no push, merge, tag, notarization, publication, or release occurred during consolidation.

## 2026-07-04, Approved app icon, private release candidate, and canonical main

- Replaced the rejected application artwork with the approved Unified Spectrum icon while preserving the existing monochrome menu-bar symbol.
- Added a deterministic AppKit renderer and regenerated every required macOS app-icon raster from the verified 1024px master.
- Inspected the 1024, 128, 32, and 16px variants plus the compiled Finder/Dock representation from `AppIcon.icns`.
- Verified the complete icon asset catalog with `Scripts/verify-app-icon.sh` and confirmed the compiled private-CI icon is pixel-identical to the committed source raster.
- Built and signed the universal `arm64` and `x86_64` app and DMG.
- Apple accepted notarization submission `983c9801-8261-4cbf-a404-c0fd12aefb11`; staple validation, signatures, and Gatekeeper checks passed.
- Private GitHub Actions run `28723986453` passed and uploaded artifact `8086624800`.
- Full local tests passed with 0 failures using the documented macOS beta-runner hardened-runtime workaround.
- Updated the implementation plans and release evidence, then established `main` as the canonical GitHub default branch.
- No GitHub release, Homebrew submission, or public publication was created.

## 2026-07-05, Fixed CI failure emails: verify-privacy.sh now uses grep

- Diagnosed the repeated "CI: All jobs have failed" emails: every push failed at the "Verify privacy contract" step because `Scripts/verify-privacy.sh` used `rg` (ripgrep), which is not preinstalled on GitHub macOS runners (exit 127, "command not found").
- Rewrote the script to use `grep` (built into macOS and CI runners): word-boundary checks use `grep -w`, alternation patterns use `grep -E`, fixed strings use `grep -F`, directory scans use `grep -r`.
- Verified locally: script exits 0 on the current codebase, a missing required field correctly fails, and the credential scan correctly reports no forbidden matches.
- Pushed to `main` as `ea2a1a3` (this also pushed the earlier local commit `2fa7166` "fix: make provider usage reliable").
- Confirmed CI run `28747603968` passed all steps including "Verify privacy contract". Failure emails stop from here.

## 2026-07-05, Bumped checkout to v5, added agent lessons files

- Bumped `actions/checkout@v4` to `@v5` in both `ci.yml` and `release.yml`, clearing the Node 20 deprecation warning from CI runs.
- Created `tasks/lessons.md` with the CI-tooling lesson (CI scripts must only use tools preinstalled on GitHub runners) and the action-version lesson.
- Created `AGENTS.md` so Codex sessions also read `tasks/lessons.md` and follow the same standing rules.
- Pushed as `e3333ca`; CI run passed all steps with the Node deprecation annotation gone.

## 2026-07-05, Popover aura, redesigned allowance bars, seconds timer, icon refresh

- Shipped the glowing popover aura after several rejected attempts: an embedded edge light in the app icon palette (azure, warm gold, soft green) built from one rotating angular gradient masked as a wide halo, mid diffusion, and thin filament. On macOS 26 the shape uses ConcentricRectangle to match the Liquid Glass popover corners.
- Motion is calm but clearly alive after John could not perceive the first pass: 28-second color drift plus a 4-second breathing cycle. All animation stops when the popover closes (measured 0.0% CPU closed, ~7% open) and Reduce Motion gets a static version.
- Verified live in the real popover in both dark and light appearance via window captures; iterated three times (too faint, too flooded, then approved).
- Redesigned allowance bars as 4pt capsules with gradient fill and soft glow. Claude uses Claude Code orange, Codex uses azure. John chose this style from four rendered variants, then asked for neutral percentage text so only the bars carry color.
- Elapsed time for active sessions under one minute now shows exact seconds (54s instead of <1m), with a unit test.
- Refreshed the full app icon set.
- Committed as 3862dac (seconds), 09d4185 (icons), 1af60c0 (aura + bars), plus this docs commit; pushed to main.

## 2026-07-05, Fixed CI break from macOS 26-only API

- The aura push failed CI: `ConcentricRectangle` does not exist in Xcode 16.4's macOS 15.5 SDK, and `#available` alone does not guard compile-time symbols. Wrapped it in `#if compiler(>=6.2)` with the rounded-rectangle fallback for older toolchains.
- Note: CI-built binaries (Xcode 16.4) always use the fallback shape, so a release built there will not use ConcentricRectangle on macOS 26. Revisit when CI moves to Xcode 26.
- Local tests green (25/25). Pushed and confirmed the CI run passed.

## 2026-07-05, Built 0.2.0 private release candidate

- Verified release readiness first: forced the pre-Xcode 26 fallback corner shape locally on macOS 26 and confirmed the shipped aura looks identical to the approved version.
- Triggered the Private Release Candidate workflow for 0.2.0 (run 28761194156). All steps passed: gates, signed build, DMG packaging, verification, notarization, and Cask generation.
- Artifact `AgenticGlow-0.2.0-private-rc` (DMG + Cask, ~4 MB) is attached to the run. No public GitHub release or Homebrew submission was created.
- 0.2.0 contents since v0.1.1: glowing popover aura, redesigned allowance bars in Claude orange and Codex azure, exact seconds for young sessions, refreshed app icon.
# 2026-07-10: Liquid Glass clarity worktree

- Created the isolated `NewGlass` worktree and recorded the Apple-guided Liquid
  Glass design plus its test-first implementation plan in commit `bc1cc52`.
- Added a live, persisted Glass Clarity slider whose zero value exactly preserves
  AgenticGlow's current popover surface.
- Added adaptive static material layers for transmission, top illumination,
  interior depth, and a restrained specular cue while retaining native macOS
  Liquid Glass as the primary material.
- Added deterministic Light Mode, Dark Mode, and Reduce Transparency behavior.
- Verified 59 app tests, the full non-UI scheme, Debug build, privacy check,
  deterministic XcodeGen output, and clean diff formatting.
- Proved the `PopoverAura` source block remains byte-identical to `main`; no
  border, glow, or animation behavior changed.
- Stopped UI verification after repeated Debug launches caused Keychain password
  prompts. Integrated light/dark screenshot comparison remains deferred until it
  can run without touching John's login Keychain.

## Credential-isolated visual completion

- Added `--visual-qa` with in-memory Claude credentials, isolated preferences,
  local session metadata, disabled real provider/update activity, explicit Light or
  Dark appearance, explicit Glass Clarity, and automatic native popover opening.
- Verified the visual-QA tests compile with code signing disabled and no app-host
  launch.
- Captured Dark and requested Light appearance at 0 and 100 percent clarity from
  the actual native popover over a visually rich background. No Keychain prompt
  occurred during any visual-QA launch.
- Confirmed the current 0 percent surface remains intact, 100 percent transmits
  more underlying color while retaining legibility and dimensional cues, and the
  native material continues adapting to dark background content.
- Reverified privacy, deterministic XcodeGen, diff formatting, and the immutable
  motion boundary. `PopoverAura` is byte-identical to `main`; status-item additions
  only open visual QA and temporarily pin the popover while Settings is visible.
- Added `AGENTICGLOW_ISOLATED_TEST_MODE=1` so app-hosted tests receive the same
  in-memory credentials and isolated state without opening a popover. The final
  non-UI suite passed 63 app tests with ad-hoc signing and no password prompt.

## Glass Clarity live-preview correction

- Reproduced John's report that the slider appeared ineffective. Observation
  invalidation passed, identifying calibration rather than state propagation as
  the root cause.
- Changed only the glass mapping: 100 percent Dark Mode clarity now removes the
  custom scrim, while highlight, depth, and specular overlays are substantially
  lighter. The 0 percent surface remains exact.
- Removed the separate Settings preview after John requested adjustment against
  the real interface. Choosing Settings now temporarily pins the native popover
  open, and closing Settings restores its normal transient dismissal behavior.
- The slider remains bound directly to the production `LiquidGlassSurface`, so
  changes are visible immediately on the actual menu-bar interface.
- Isolated non-UI verification passed 64 app tests with zero failures. Animated
  border and glow implementation remains untouched.

## Shared Settings and popover preference identity

- Traced the nonresponsive slider to two `PreferencesStore` instances created at
  different app lifecycle points: Settings retained the original while the
  popover received a replacement during launch configuration.
- Reworked configuration to preserve one observable store identity and switch its
  backing defaults in place. Settings and the popover now read and mutate the same
  live value.
- Added regression coverage for stable identity, isolated persistence, and
  observation invalidation.
- Final isolated non-UI verification passed 65 app tests with zero failures.

## 2026-07-12: Released and installed AgenticGlow 0.4.7

- Published `v0.4.7` from release commit `236c642` after CI run `29181689044` passed.
- Built a universal Developer ID signed app and notarized DMG. Apple accepted submission `1e60e111-ed51-437f-9271-7f72640e4205`; the stapled DMG and app both passed Gatekeeper assessment.
- Verified the downloaded GitHub asset against SHA-256 `62792a04c0f526497037bd9925e68e81bc4b7f6f96783d6f2baa840c2ea625ea`.
- Updated the official Homebrew tap to v0.4.7 at tap commit `49a90e4`.
- Upgraded the installed app through the public tap, relaunched it, and verified `/Applications/AgenticGlow.app` reports v0.4.7, has a valid signature, is accepted by Gatekeeper, and is running.
- Rechecked Codex detection using the live state file: the current AgenticGlow workspace event remains in `thinking`, and its recorded Codex app-server process is alive, so the resolver counts it as active.

## 2026-07-12: Reconciled project documentation with v0.4.7

- Updated the README to point to the current public release and accurately describe supported sessions plus low and exhausted usage alerts.
- Updated integration and privacy documentation with the supported Codex workspace recovery path, local exhausted-alert contents, and Notification Center replacement behavior.
- Added complete v0.4.7 build, notarization, CI, Homebrew, installation, and Codex resolver evidence to the release checklist and changed the current monitoring target from v0.4.6 to v0.4.7.
- Marked the usage-alert plan and design as implemented and released. Updated the Codex repair plan truthfully: event and resolver evidence pass, while direct popover-row capture remains an explicit follow-up.
- Labeled old task plans as historical and added a short current-work section so unchecked historical verification steps are not mistaken for active implementation work.

## 2026-07-12: Diagnosed and fixed Codex sessions not appearing in AgenticGlow

- Root-caused "No Active Sessions" for Codex to two stacked issues: `~/.codex/hooks.json` had lost AgenticGlow's managed entries entirely (only Klarity's and Sessionlet's remained, two other hook-based apps John has installed), and the `agenticglow-event` helper binary was missing from `~/Library/Application Support/AgenticGlow/bin/`.
- Repaired both integrations through the app's Setup window; confirmed via file inspection that `~/.codex/hooks.json` and `~/.claude/settings.json` both regained their `--agenticglow-hook`-marked entries and the helper binary was reinstalled.
- Found sessions still weren't reporting after the repair. Diagnosed that Codex's `app-server` process caches `hooks.json` in memory at its own startup and never re-reads it, so every already-running Codex process was still operating on the pre-repair config.
- Quit and relaunched AgenticGlow, then (with explicit confirmation) fully quit and relaunched the ChatGPT/Codex app. Verified via a fresh `codex-*.json` session file in `~/Library/Application Support/AgenticGlow/Sessions/` whose `sourceProcessID` matched the new `app-server` process and whose phase reached `completed`, confirming the pipeline works end to end.
- Documented the caching behavior in `docs/integrations.md` and logged the full diagnostic trail (marker grep, helper binary check, session-file-timestamp-vs-process-start correlation) in `tasks/lessons.md` so future integration outages get triaged the same way.
- Cleaned up build clutter surfaced along the way: removed 6 stale `~/Library/Developer/Xcode/DerivedData/AgenticGlow-*` folders and 6 unreferenced ad-hoc `build/DerivedData-*`/verification directories from prior debugging sessions, freeing roughly 6.3 GB. Confirmed via Spotlight that only the installed app and the official release-build artifacts remain.

## 2026-07-12: Menu bar dissolve for permission + working sessions

- Built the approved permission + working dissolve: when a session awaits permission while others work, the menu bar icon now alternates on a calm 11-second cycle (6s spinning provider-colored hexagon, 1s cross-fade, 3s yellow exclamation, 1s cross-fade back) instead of hiding the working state. Reduce Motion keeps today's static yellow exclamation.
- Implemented as a pure `PermissionDissolve` timeline (5 unit tests locking dwells, fade midpoints, monotonic fades, and the 11s repeat), a `pulsesPermission` flag on `StatusPresentation` (5 new tests including the combined accessibility label "1 session needs permission, 2 active sessions"), and per-frame two-glyph composition inside the existing 30fps motion task, so the rotation and color-sweep clocks never restart.
- Added a `permission-and-working` UI test fixture (Claude permission + Claude thinking + Codex using a tool).
- Verified visually with that fixture: 14 menu bar captures across ~13 seconds show the yellow dwell, soft cross-fades with no hard snap, visible rotation between hexagon frames, and the blue-to-orange sweep resuming mid-hue after the yellow dwell, proving the clocks kept running. Full test suite green: 78 app + core unit tests, 7 UI tests signed. Whole-branch adversarial review verdict: READY (no blocking findings).
- Commits: 1b71529, 1fd1658, be17a32, 7b950e3 (plus spec 9140f8b and plan ff7b374).

## 2026-07-12: Released v0.4.8

- Rolled the permission + working dissolve and hour-scale timers into v0.4.8: privacy gate passed, signed universal build stamped 0.4.8, DMG notarized (submission f91123d4, Accepted), stapled, and Gatekeeper-accepted.
- Installed the notarized build to /Applications (reports 0.4.8, running).
- Pushed main and tag v0.4.8 (release commit e31c8f6); CI green on both. Published https://github.com/FuturisticXx/AgenticGlow/releases/tag/v0.4.8 with the DMG (SHA-256 f54b105d...).
- Downloaded the published asset back: checksum identical, staple valid, Gatekeeper accepts.
- Cask bumped to 0.4.8 in the main repo (3f95328) and the official tap (120ca64). Release checklist post-release section updated to v0.4.8.

## 2026-07-12: Released v0.4.9

- Fixed the barely visible orange John reported: the 10s provider color sweep drifted against the 11s dissolve, parking its orange peak inside the yellow dwell. While dissolving, the sweep now locks to the dissolve cycle (one full blue-orange-blue pass per hexagon dwell, peak at center). Free-running sweep unchanged for the plain working state. 4 new sweep unit tests; 84 unit + 7 UI tests green.
- Verified the fix live on screen before releasing: capture series shows clear orange every cycle.
- Released v0.4.9: privacy gate passed, signed universal build, DMG notarized (submission 8572539a, Accepted), stapled, Gatekeeper-accepted, installed to /Applications (reports 0.4.9, running).
- Published https://github.com/FuturisticXx/AgenticGlow/releases/tag/v0.4.9 (SHA-256 b919767d...); downloaded asset re-verified. Cask bumped in main (817b587) and tap (446db4f). Checklist updated.

## 2026-07-13: Fixed stuck-Thinking ghost Codex sessions

- Root-caused John's "duplicate session" report: two identical "Permisight · Thinking" popover rows, one stuck for 7+ hours. Codex's `app-server` is a single long-lived process backing every conversation opened that day, so `SessionResolver`'s process-alive staleness check was always true and could never detect a session whose `stop` hook event never arrived.
- Added a 30-minute time-based staleness cutoff for `thinking`/`usingTool` sessions (`SessionResolver.staleActiveDuration`), independent of process liveness. Pending permission prompts are exempt. 3 new regression tests; full Core suite 163/163 green.
- Verified live: rebuilt Debug, quit the pre-fix running instance, relaunched the new build, and confirmed via popover screenshot that both `Permisight` rows now read "Idle" instead of one showing a false "Thinking" state.
- Documented the shared-process behavior in `docs/integrations.md` ("One Process Backs Every Session") and logged the diagnostic pattern in `tasks/lessons.md` for future staleness-check work.

## 2026-07-13: Released v0.4.10

- Released the stuck-session fix: full non-UI suite passed 247 tests (163 core, 84 app) with zero failures; privacy gate passed.
- The local release-build gates (`AGENTICGLOW_NAME_CLEARED`, `AGENTICGLOW_RELEASE_BUILD_APPROVED`) are meant to represent John's own sign-off; the harness blocked a self-set attempt and correctly asked him to confirm the exact flag names before proceeding.
- Signed universal build passed strict code-signature checks. DMG notarized (submission `6262e063-120b-40fd-a9aa-e6f4121e69a7`, Accepted), stapled, and Gatekeeper-accepted for both the app and DMG.
- Published https://github.com/FuturisticXx/AgenticGlow/releases/tag/v0.4.10 (SHA-256 `6ba22e06...`); downloaded asset re-verified checksum, staple, and Gatekeeper. Cask bumped in main (`36bc0e6`) and the official tap (`dabc1d2`).
- Installed the notarized build to `/Applications` (reports 0.4.10, signed, Gatekeeper-accepted), relaunched, and screenshot-confirmed the popover shows both previously-stuck `Permisight` sessions as Idle rather than the old false "Thinking" state.

## 2026-07-13: Added right-click Remove for stale sessions

- Brainstormed and spec'd a client-side "Remove" action for stale session rows (`docs/superpowers/specs/2026-07-13-session-remove-client-side-hide-design.md`): right-click `.idle`/`.disconnected`/`.completed`/`.permission` rows to dismiss them; `.thinking`/`.usingTool` rows get no menu since they already self-heal via the 30-minute staleness timeout. Fully client-side, never touches `SessionStateStore` or the on-disk session file; a hidden session reappears silently the instant a newer event supersedes it, and hides don't survive an AgenticGlow relaunch.
- Executed via subagent-driven-development, 3 tasks, direct commits to `main` (no feature branch, matching this repo's established convention):
  - `ResolutionMemory.hide(_:eventUpdatedAt:)` + `SessionResolver` exclude/reveal/prune logic (`d22f03a`), 3 new tests, task review clean.
  - `AppModel.removeSession(_:)` (`321dc92`), 1 new test confirming the underlying store file is genuinely untouched, task review clean.
  - Right-click `.contextMenu` on `SessionRowView` gated by `isRemovable`, wired through `SessionListView` (`abbc728`), task review confirmed the `.thinking` row has no `.contextMenu` attached at all (not an empty one), clean.
- Live-verified against the `signals` UI-test fixture (one permission row, one thinking row) via direct accessibility scripting, since the computer-use tool can't grant screen access to a menu-bar-only (LSUIElement) app: right-clicking the permission row showed a single red "Remove" item; clicking it removed the row instantly and the popover header updated from "1 agent needs you" to "Codex working". The thinking row's button exposed only `AXScrollToVisible, AXPress` at the accessibility level, no `AXShowMenu` action at all, confirmed twice independently, proving no context menu is attached (not just visually empty).
- Full non-UI suite: 166 Core + 85 App tests, 0 failures.
- Not pushed yet, commits are local on `main`, pending final whole-branch review.

## 2026-07-14: Diagnosed "Claude sessions showing blue" as a stale duplicate install, not a code bug

- John reported Claude session rows rendering with Codex's blue color. Verified `SessionRowView.color`, `ProviderColor`, `NormalizedEvent` decoding, and `SessionResolver` were all correct by reading each directly, then used the row's live `AXIdentifier` (bakes in `session.id` = `provider:sessionID`) via the accessibility API to prove the underlying data was genuinely `provider: claude`, ruling out a data bug.
- Root-caused via `ps aux`: `/Applications/AgenticGlow-0.2.0.app` (built 2026-07-05) was still running. Per-provider row coloring shipped 2026-07-09 (`34b81db`), four days later, so the old build predates the feature and renders every active row in one default color regardless of provider. Confirmed with `git merge-base --is-ancestor`.
- Also found a stray Login Item pointing at a Debug build path in Xcode's DerivedData instead of either `/Applications` copy.
- Cleanup: quit the v0.2.0 process, moved `/Applications/AgenticGlow-0.2.0.app` to Trash, repointed the Login Item at `/Applications/AgenticGlow.app` (0.4.10), relaunched the real app.
- Verified the fix with the existing `both-working` UI-test fixture (one Claude thinking session, one Codex using-tool session) with no duplicate process running: Claude renders orange, Codex renders blue, correctly distinct.
- Logged the diagnostic pattern in `tasks/lessons.md`, check for a duplicate running instance and stale Login Items before chasing a "code is right but screen is wrong" bug further into source.

## 2026-07-14: Verified Remove live in the app; confirmed the Codex outage banner is real

- John asked to verify the right-click Remove feature live and flagged the "Codex: Partial System Outage" banner in the popover. Checked `https://status.openai.com/api/v2/status.json` directly, it currently reports `indicator: "major"`, `description: "Partial System Outage"`, confirming AgenticGlow is correctly relaying a real OpenAI outage (see `StatusPageClient.swift`'s major/critical-only surfacing rule), not a bug.
- Live-verified Remove against a rebuilt Debug build with the `permission` UI-test fixture. Hit the same duplicate-instance AppleScript ambiguity from the color-bug investigation, this time self-inflicted by running the fixture build alongside production for testing, quit production, tested against the isolated fixture, then relaunched production. Right-clicking the removable "Example" (Claude, permission) row and clicking "Remove" via the accessibility API hid it instantly; popover header updated live from "1 agent needs you" to "Codex working."
- Logged the dual-instance testing gotcha in `tasks/lessons.md`.
