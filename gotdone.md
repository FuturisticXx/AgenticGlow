# Got done

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
