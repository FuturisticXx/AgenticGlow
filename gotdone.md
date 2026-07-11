# Got done

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

## 2026-07-05 — Public release and Homebrew distribution

- Published the AgenticGlow repository and releases `v0.1.0` and `v0.1.1` publicly.
- Verified the public signed and notarized v0.1.1 DMG at SHA-256 `ead3891c296770f8e455c9495f68987530e24a96197539287dbbd2bcf14aec35`.
- Reproduced and fixed the Homebrew uninstall hang caused by command-mode cleanup not exiting.
- Added `Scripts/verify-uninstall-command.sh` and verified it against the signed release app.
- Published the official Homebrew tap at `FuturisticXx/homebrew-agenticglow`.
- Verified Homebrew install, launch, uninstall, integration cleanup, removal, reinstall, signature, Gatekeeper status, and relaunch for version 0.1.1.
- Documented that an upstream `homebrew/homebrew-cask` PR is deferred until AgenticGlow meets Homebrew's self-submission notability threshold.

## 2026-07-04 — Standalone repository consolidation

- Replaced the linked AgenticGlow worktree with a self-contained repository at the same canonical path.
- Archived superseded Task 9 source and tests on local branch `archive/task-9-superseded` at commit `77fe3bb` without merging it into `main`.
- Preserved the old Devin work as a verified binary patch, a separate source archive, and local recovery branch `archive/devin-task-11-base`.
- Created and verified a complete all-refs Git bundle at `/Volumes/Liquid/AgenticGlow-Migration-Backup/AgenticGlow-all.bundle`.
- Removed the obsolete `AgenticGlow-task9`, `AgenticGlow-linked-backup`, and `AgenticGlow-devin-task-11` directories after all recovery gates passed.
- Verified deterministic project generation, 151 tests with 0 failures, privacy and standalone-helper checks, icon assets, legacy-name removal, and universal `x86_64 arm64` Release binaries.
- Kept the canonical repository on local `main`; no push, merge, tag, notarization, publication, or release occurred during consolidation.

## 2026-07-04 — Approved app icon, private release candidate, and canonical main

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

## 2026-07-05 — Fixed CI failure emails: verify-privacy.sh now uses grep

- Diagnosed the repeated "CI: All jobs have failed" emails: every push failed at the "Verify privacy contract" step because `Scripts/verify-privacy.sh` used `rg` (ripgrep), which is not preinstalled on GitHub macOS runners (exit 127, "command not found").
- Rewrote the script to use `grep` (built into macOS and CI runners): word-boundary checks use `grep -w`, alternation patterns use `grep -E`, fixed strings use `grep -F`, directory scans use `grep -r`.
- Verified locally: script exits 0 on the current codebase, a missing required field correctly fails, and the credential scan correctly reports no forbidden matches.
- Pushed to `main` as `ea2a1a3` (this also pushed the earlier local commit `2fa7166` "fix: make provider usage reliable").
- Confirmed CI run `28747603968` passed all steps including "Verify privacy contract". Failure emails stop from here.

## 2026-07-05 — Bumped checkout to v5, added agent lessons files

- Bumped `actions/checkout@v4` to `@v5` in both `ci.yml` and `release.yml`, clearing the Node 20 deprecation warning from CI runs.
- Created `tasks/lessons.md` with the CI-tooling lesson (CI scripts must only use tools preinstalled on GitHub runners) and the action-version lesson.
- Created `AGENTS.md` so Codex sessions also read `tasks/lessons.md` and follow the same standing rules.
- Pushed as `e3333ca`; CI run passed all steps with the Node deprecation annotation gone.

## 2026-07-05 — Popover aura, redesigned allowance bars, seconds timer, icon refresh

- Shipped the glowing popover aura after several rejected attempts: an embedded edge light in the app icon palette (azure, warm gold, soft green) built from one rotating angular gradient masked as a wide halo, mid diffusion, and thin filament. On macOS 26 the shape uses ConcentricRectangle to match the Liquid Glass popover corners.
- Motion is calm but clearly alive after John could not perceive the first pass: 28-second color drift plus a 4-second breathing cycle. All animation stops when the popover closes (measured 0.0% CPU closed, ~7% open) and Reduce Motion gets a static version.
- Verified live in the real popover in both dark and light appearance via window captures; iterated three times (too faint, too flooded, then approved).
- Redesigned allowance bars as 4pt capsules with gradient fill and soft glow. Claude uses Claude Code orange, Codex uses azure. John chose this style from four rendered variants, then asked for neutral percentage text so only the bars carry color.
- Elapsed time for active sessions under one minute now shows exact seconds (54s instead of <1m), with a unit test.
- Refreshed the full app icon set.
- Committed as 3862dac (seconds), 09d4185 (icons), 1af60c0 (aura + bars), plus this docs commit; pushed to main.

## 2026-07-05 — Fixed CI break from macOS 26-only API

- The aura push failed CI: `ConcentricRectangle` does not exist in Xcode 16.4's macOS 15.5 SDK, and `#available` alone does not guard compile-time symbols. Wrapped it in `#if compiler(>=6.2)` with the rounded-rectangle fallback for older toolchains.
- Note: CI-built binaries (Xcode 16.4) always use the fallback shape, so a release built there will not use ConcentricRectangle on macOS 26. Revisit when CI moves to Xcode 26.
- Local tests green (25/25). Pushed and confirmed the CI run passed.

## 2026-07-05 — Built 0.2.0 private release candidate

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
- Proved the `PopoverAura` source block and `StatusItemController.swift` remain
  byte-identical to `main`; no border, glow, or animation behavior changed.
- Stopped UI verification after repeated Debug launches caused Keychain password
  prompts. Integrated light/dark screenshot comparison remains deferred until it
  can run without touching John's login Keychain.

## Credential-isolated visual completion

- Added `--visual-qa` with in-memory Claude credentials, isolated preferences,
  empty session state, disabled real provider/update activity, explicit Light or
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
  motion boundary. `PopoverAura` is byte-identical to `main`; the only status-item
  change is the visual-QA entry point that invokes the existing toggle method.
- Added `AGENTICGLOW_ISOLATED_TEST_MODE=1` so app-hosted tests receive the same
  in-memory credentials and isolated state without opening a popover. The final
  non-UI suite passed 63 app tests with ad-hoc signing and no password prompt.
