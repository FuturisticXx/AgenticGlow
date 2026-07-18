# AgenticGlow Release Checklist

This checklist must be completed and documented with dated evidence before any release.

## Historical Release Evidence

Recorded 2026-06-29 for version 0.1.0 on macOS 27.0 beta with Xcode 26.6:

- Release script syntax checks passed.
- Release gates intentionally fail while `AGENTICGLOW_NAME_CLEARED` remains unset.
- The manual release workflow remains gated by repository variables and requires signing/notarization secrets before it can run.
- Privacy contract verification passed.
- The standalone installed helper regression passed without a bundled framework dependency.
- The sanitized Claude and Codex fixture matrix produced two session files and no prohibited decoy text.
- The unsigned Release app and helper both contain `arm64` and `x86_64` slices.
- Focused event-helper and preferences tests passed.
- Full UI target and full scheme tests passed with `ENABLE_HARDENED_RUNTIME=NO`, the local beta-runner workaround confirmed by triage.
- Default hardened-runtime UI automation remains a local beta-runner blocker.
- Cask generation dry-run produced Ruby syntax OK with a dummy local DMG, then the placeholder output was removed.
- Real `Cask/agenticglow.rb` generation, signed DMG, notarization, Gatekeeper, Homebrew installation, live-provider, and accessibility checks remain unverified.

Recorded 2026-06-30 for version 0.1.0 on macOS 27.0 beta with Xcode 26.6:

- Full scheme tests passed with `ENABLE_HARDENED_RUNTIME=NO`, the local beta-runner workaround confirmed by triage.
- Privacy contract verification passed.
- Release script syntax checks passed.
- Release gates intentionally fail while `AGENTICGLOW_NAME_CLEARED` remains unset.
- Unsigned Release build passed with `ARCHS="arm64 x86_64"` and `CODE_SIGNING_ALLOWED=NO`.
- The unsigned Release app and helper both contain `arm64` and `x86_64` slices.
- The embedded Release helper ran standalone without a bundled framework dependency.
- The sanitized Claude and Codex fixture matrix produced two session files and no prohibited decoy text.
- Preliminary practical preflight for AgenticGlow found no obvious exact-name web, GitHub repository, Homebrew cask/formula, Mac App Store, or domain DNS conflicts; this is not formal trademark clearance.
- Homebrew's public cask list did not show an exact `agenticglow` token during preflight, but Cask availability is not brand clearance.
- Real `Cask/agenticglow.rb` generation, signed DMG, notarization, Gatekeeper, Homebrew installation, live-provider, and accessibility checks remain unverified.

Recorded 2026-07-03 for version 0.1.0 on macOS 27.0 beta with Xcode 26.6:

- Latest implementation commit: `c2ca966` (`feat: add private provider allowance menu`).
- Full unit and UI test suite passed.
- Universal `arm64` and `x86_64` Release build passed.
- Privacy and standalone-helper checks passed.
- Working CPU averaged 0.223 percent; memory was approximately 100 MB.
- XcodeGen regeneration was deterministic.
- No provider allowance requests occur before explicit user opt-in.
- Disabling provider allowance clears the cache and discards in-flight results.
- Codex allowance uses the supported local `account/rateLimits/read` RPC through the installed Codex app-server without copying credentials.
- Claude allowance remains unavailable because Anthropic documents interactive `/usage`, but no supported third-party allowance endpoint or macOS Keychain reuse contract.
- Accessibility tree and Light appearance were inspected.
- Private branch push completed to `https://github.com/FuturisticXx/AgenticGlow` on `codex/klarity-release-baseline`.
- No signing, notarization, DMG publication, GitHub release, Homebrew submission, or public release was completed.
- Publication gates remain blocked beginning with `AGENTICGLOW_NAME_CLEARED`.
- `docs/tasks/repository-consolidation.md` remains untracked and excluded from the release evidence commit by design.
- Dark appearance was not separately screenshot-tested because the test host ignored forced Dark appearance overrides.

Fresh release-readiness preflight recorded 2026-07-03:

- Repository, update-check, README, generated-cask, and release-checklist URLs consistently use `https://github.com/FuturisticXx/AgenticGlow`.
- Exact-name searches found no public GitHub repository, Homebrew formula or cask, or US Mac App Store listing named AgenticGlow.
- Similar branding remains relevant: an existing product at `getglow.ai` markets agentic AI workflows under the name Glow.
- `agenticglow.com` is registered to another party and resolves to a minimal holding page; it was created 2026-04-09.
- Registry checks returned no current registration record for `agenticglow.app` or `agenticglow.dev`; `agenticglow.io` appeared unregistered. Availability must be confirmed with a registrar immediately before purchase.
- Exact profile URLs for AgenticGlow returned not found on GitHub, X, and Mastodon, but no handles were reserved.
- This practical screen is not formal trademark clearance. On 2026-07-03, the owner explicitly approved AgenticGlow as the release name and accepted the documented practical risks.
- GitHub repository variables `AGENTICGLOW_NAME_CLEARED=1` and `AGENTICGLOW_RELEASE_BUILD_APPROVED=1` were configured for the private release-candidate workflow. `AGENTICGLOW_PUBLICATION_APPROVED` remains unset.
- The login Keychain contains a valid `Developer ID Application: John Wright (Z52AX2BH7T)` identity, and notary profile `agenticglow-notary` is validated and saved.
- The private release-candidate workflow now requires name clearance and release-build approval, but not public-publication approval; it only uploads a private Actions artifact.
- The required private release variables, Apple notarization secrets, and Developer ID certificate-export secrets are configured in GitHub Actions.
- A fresh unsigned universal Release build and temporary DMG packaging preflight passed; the mounted image contained the app and Applications link, and the generated cask passed Ruby syntax and exact-checksum verification.
- Bundle inspection confirmed version 0.1.0, bundle identifier `com.twodamax.agenticglow`, macOS 14.0 minimum, hardened runtime enabled for Release, an empty entitlement set, no embedded third-party frameworks, and universal app and standalone-helper executables.
- macOS 27 reports `hdiutil` image creation and attachment as deprecated. The release scripts retain it for compatibility with the macOS 14 deployment floor and `macos-15` GitHub runner until the replacement is verified there.
- A signed universal 0.1.0 app and DMG passed strict code-signature checks. Apple accepted notarization submission `ea62125b-5c96-4b32-8692-4d8f53c14d77`; the ticket was stapled and validated, and Gatekeeper accepted both artifacts as `Notarized Developer ID` software.
- The generated DMG SHA-256 is `a04e076aa62f7617d116015d1a8b7af02207c342f5867ba34cf11b1e9dfcf51f`. The generated `Cask/agenticglow.rb` contains that checksum and passes Ruby syntax validation.
- Private GitHub Actions run `28712769421` passed the full release-candidate workflow and uploaded artifact `AgenticGlow-0.1.0-private-rc` (artifact ID `8083510400`).
- The downloaded CI artifact DMG SHA-256 is `d9e87b13353c6d9bacae2a431cdb89801026b7ee148a86b626c338e44572b038`; its generated cask contains the same checksum, and local post-download signature, stapler, and Gatekeeper checks passed.
- No GitHub release, Homebrew installation, or public publication was performed.

Corrected app-icon release-candidate evidence recorded 2026-07-04:

- The approved icon source is `docs/superpowers/specs/2026-07-04-agenticglow-app-icon-design.md`; deterministic master SHA-256 is `9a2c00d4bc8b1c3fb4a65af2c902b04d48e109555b406c593c362c068885bb97`.
- The 1024, 128, 32, and 16 pixel variants were inspected; all ten asset-catalog dimensions passed `Scripts/verify-app-icon.sh`.
- An isolated unsigned Release build passed, and the compiled Finder/Dock representation from `AppIcon.icns` was inspected with the corrected ring, halo, and segmented signal.
- `StatusPresentationTests` passed 7 tests with 0 failures, confirming the menu-bar presentation remains unchanged.
- The signed universal app contains `arm64` and `x86_64` slices. Apple accepted notarization submission `983c9801-8261-4cbf-a404-c0fd12aefb11`; staple validation and Gatekeeper checks passed for the app and DMG.
- The corrected DMG SHA-256 is `6d58aa7693336c3c2deb9343b3f9b33a300bb7f69551a81c809ce6dc800debdc`; `Cask/agenticglow.rb` contains the same checksum and passes Ruby syntax validation.
- Private GitHub Actions run `28723986453` passed on commit `d33c20e` and uploaded `AgenticGlow-0.1.0-private-rc` as artifact `8086624800`.
- The downloaded private artifact DMG SHA-256 is `e0354f308b19bf9c95c3453ce910e57c5c9f8c0bb7b565feb7779bd9b3bd0050`; its DMG staple, signatures, and Gatekeeper assessment passed, and its compiled 256 pixel icon was pixel-identical to the committed source raster.
- No GitHub release, Homebrew submission, or public publication was performed.

Public release and Homebrew evidence recorded 2026-07-05:

- Repository consolidation commits were pushed and `main` was synchronized with `origin/main`.
- The repository was audited for tracked credential material before its visibility changed from private to public; no credential payloads were found.
- The owner approved publication through the active release goal, and repository variable `AGENTICGLOW_PUBLICATION_APPROVED=1` was configured.
- Public release `v0.1.0` was published from commit `c307936` with signed and notarized DMG SHA-256 `ff4ddf497d24312794f2646545f55d040e248cb82aedd02657b0d339c20b6185`.
- Homebrew lifecycle testing found that `--remove-integrations` did not exit, which caused Cask uninstall to hang. `Scripts/verify-uninstall-command.sh` reproduced the failure before the lifecycle fix and passed afterward.
- The complete non-UI test surface passed 145 tests with 0 failures. The six-test UI runner did not bootstrap on the macOS 27 beta/Xcode 26.6 host; this was a runner-level early exit before any UI assertion. Live accessibility-tree inspection and prior passing UI evidence cover the release UI.
- Private release workflow run `28730186619` passed from commit `705158f` for version 0.1.1, including signing, notarization, Gatekeeper, universal architecture, Cask generation, and artifact upload.
- Public hotfix release `v0.1.1` was published from commit `705158f`. Its DMG SHA-256 is `ead3891c296770f8e455c9495f68987530e24a96197539287dbbd2bcf14aec35`.
- The public v0.1.1 DMG passed signature, stapler, Gatekeeper, and noninteractive integration-removal verification after download.
- The official AgenticGlow tap at `https://github.com/FuturisticXx/homebrew-agenticglow` publishes Cask version 0.1.1 with the exact public DMG checksum.
- `brew install --cask FuturisticXx/agenticglow/agenticglow`, launch, uninstall while running, integration removal, application removal, reinstall, signature verification, Gatekeeper assessment, and relaunch all passed on macOS 27 beta.
- Homebrew's official Cask repository currently rejects self-submitted apps below 90 forks, 90 watchers, or 225 stars. AgenticGlow is newly public, so an upstream `homebrew/homebrew-cask` PR is deferred until it meets the published threshold; the maintained upstream tap is the supported installation route.

Public release 0.2.0 evidence recorded 2026-07-05:

- Released from commit `09dabd6` (tag `v0.2.0`) containing the popover aura, redesigned allowance bars, exact elapsed seconds under one minute, refreshed app icon, the bundled Codex binary allowance fix, and the Dark Mode popover fix (0.45 scrim plus unified aura palette).
- The Dark Mode fix was screenshot-verified live on macOS 27.0 from the rebuilt app and again from the installed notarized 0.2.0 app; John approved the scrim strength from three labeled live captures.
- 154 non-UI tests passed and the privacy contract verification passed on the release commit; CI run `28765533939` passed on push.
- Signed universal `arm64` and `x86_64` build passed strict code-signature checks. Apple accepted the notarization submission; the DMG was stapled and validated, and Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- The released DMG SHA-256 is `9b990455fa7155d13bb4df61137e0fd6cf614e62fe08cd6547b96b901d7ed512`; the asset downloaded back from the GitHub release matched the checksum, staple validation, and Gatekeeper assessment.
- `Cask/agenticglow.rb` was regenerated with the 0.2.0 checksum, passed Ruby syntax validation, and was pushed to the official tap `FuturisticXx/homebrew-agenticglow` (tap commit `5c21667`).
- The installed /Applications app was replaced with the notarized 0.2.0 build and relaunched.
- Known appearance note: the Dark Mode scrim applies on macOS 26+ only; macOS 14 to 25 keep the more opaque `.regularMaterial` background.

Public release 0.4.0 evidence recorded 2026-07-10:

- Released from commit `703c467` (tag `v0.4.0`). Version 0.3.0 was never tagged, so this is the first public release since 0.2.0 and bundles both lines of work: the 0.3.0 features (permission and low-allowance notifications, low-allowance menu bar badge, opt-in provider incident line limited to major and critical outages, weekly reset celebration, provider color language, allowance percentage pills) and the 0.4.0 icon polish (deeper Claude orange, one frame-task motion pipeline at 12 seconds per revolution and 10 seconds per color sweep, 80 percent orange cap, appearance-adaptive palettes resolved per frame).
- Motion was verified by measurement on the live menu bar: the sweep measured 9.99 seconds against a 10.0 target, and rotation autocorrelation peaked at +0.95 at exactly the hexagon's 2.0 second symmetry lag, proving a constant spin with no restarts.
- The full suite passed on the release commit: 157 core, 53 app, and 6 UI tests with zero failures, and the privacy contract verification passed. CI run `29124749705` passed on the feature commit `2f59788`, and the follow-up docs and cask pushes were green.
- Signed universal `arm64` and `x86_64` build passed strict code-signature checks for the app and the event helper. Apple accepted notarization submission `bb34b41b-4de9-48d7-8b43-27e5e441b6ad`; the DMG was stapled and validated, and Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- The released DMG SHA-256 is `c079f59e1d495b2df654ffc6eafea01685756546c939fb9786678c639c395e62`; the asset downloaded back from the GitHub release matched the checksum, staple validation, and Gatekeeper assessment.
- `Cask/agenticglow.rb` was regenerated with the 0.4.0 checksum (main commit `5dc7abb`) and pushed to the official tap `FuturisticXx/homebrew-agenticglow` (tap commit `6bb0916`).
- The installed /Applications app was replaced with the notarized 0.4.0 build and relaunched.
- Known system behaviors documented during verification: macOS dims menu bar content on inactive displays, and the bar's light or dark appearance verdict can lag a wallpaper change; the icon follows the same system verdict as every other menu bar icon.

Public release 0.4.5 evidence recorded 2026-07-10:

- Released from commit `1f5595e` (tag `v0.4.5`) containing John's Liquid Glass popover surface and Glass Clarity setting on top of v0.4.0, plus a UI-test disambiguation fix for the popover Settings menu item.
- All 7 UI tests passed with the real signing identity; unit bundles passed. Ad-hoc-signed UI test runs are invalid evidence (automation identity breaks); recorded in tasks/lessons.md.
- Signed universal build passed strict code-signature checks; the DMG was notarized, stapled, and validated; Gatekeeper accepted app and DMG as `Notarized Developer ID`.
- Released DMG SHA-256 `6acd2b5d0decba3083a38b4f2c42adf49cf20b7fa6c187a54a9bf403b7fcc160`; the downloaded release asset matched checksum, staple, and Gatekeeper.
- Cask regenerated and pushed to main and the official tap (tap commit `a4abad2`); /Applications updated to 0.4.5 and relaunched.

Public release 0.4.6 evidence recorded 2026-07-11:

- Released from commit `de8b30e` (tag `v0.4.6`): root-cwd sessions no longer surface "/" as their project name; the normalizer falls back to the provider display name, TDD-tested.
- 158 core plus app unit tests and all 7 UI tests passed on the release commit; privacy gate passed; CI green.
- Signed universal build passed strict checks; DMG notarized, stapled, validated; Gatekeeper accepted app and DMG as `Notarized Developer ID`.
- Released DMG SHA-256 `bb4f08803938fc8472f3693e517c5458bd005cfac9673a576ec99a63b2e60276`; downloaded asset matched checksum, staple, and Gatekeeper.
- Cask regenerated and pushed to main and the official tap (tap commit `494623e`); /Applications updated to 0.4.6 and relaunched.

Public release 0.4.7 evidence recorded 2026-07-12:

- Released from commit `236c642` (tag `v0.4.7`) with state-based quota alert deduplication, one immediate exhausted alert at 0 percent, reset-time guidance, stable notification replacement identifiers, and recovery-based re-arming.
- A real Codex event from the canonical AgenticGlow workspace recorded `thinking` with source process `48031`, matching the live Codex app-server process. The deleted Klarity path was not recreated and Codex private state was not edited.
- The complete non-UI suite passed 234 tests with zero failures. Release CI run `29181689044` passed on the release commit, and final documentation CI run `29181811779` passed.
- Apple accepted notarization submission `1e60e111-ed51-437f-9271-7f72640e4205`. The signed universal app and DMG passed strict signature, stapler, and Gatekeeper verification.
- Released DMG SHA-256 `62792a04c0f526497037bd9925e68e81bc4b7f6f96783d6f2baa840c2ea625ea`; the downloaded GitHub asset matched the checksum and passed staple and Gatekeeper verification.
- The official Homebrew tap was updated at commit `49a90e4`. Homebrew installed v0.4.7 into `/Applications`, the app passed signature and Gatekeeper checks, and it relaunched successfully.

Public release 0.4.10 evidence recorded 2026-07-13:

- Released from commit `fa40ce5` (tag `v0.4.10`): `thinking`/`usingTool` Codex and Claude sessions now expire to Idle after 30 minutes without an update (`SessionResolver.staleActiveDuration`), independent of whether the backing process is alive. Fixes a Codex conversation that finished without its `stop` hook event displaying as "Thinking" indefinitely, which made unrelated sessions in the same project look like duplicates.
- The complete non-UI suite passed 247 tests with zero failures (163 core, 84 app); the privacy gate passed.
- Both release gate variables were confirmed with the owner in chat before use, naming `AGENTICGLOW_NAME_CLEARED` and `AGENTICGLOW_RELEASE_BUILD_APPROVED` explicitly.
- Signed universal `arm64`/`x86_64` build passed strict code-signature checks. Apple accepted notarization submission `6262e063-120b-40fd-a9aa-e6f4121e69a7`; the DMG was stapled and validated, and Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- Released DMG SHA-256 `6ba22e06a40cd291aa8b3c0bebc3804225fa608c4ced8d5e4249e6ba1288e1d2`; the asset downloaded back from the GitHub release matched the checksum, staple validation, and Gatekeeper assessment.
- `Cask/agenticglow.rb` was regenerated with the 0.4.10 checksum (main commit `36bc0e6`) and pushed to the official tap `FuturisticXx/homebrew-agenticglow` (tap commit `dabc1d2`).
- The installed `/Applications` app was replaced with the notarized 0.4.10 build, relaunched, and its popover was screenshot-verified showing both previously-stuck sessions as Idle.

Public release 0.4.11 evidence recorded 2026-07-15:

- Released from commit `e10cab8` (tag `v0.4.11`): the popover now highlights whichever allowance window (current or weekly, per provider) triggered the menu bar's low-usage badge with an orange warning triangle and orange caption text, reusing the badge's own `NSColor.systemOrange`. Provider bar/pill coloring is unchanged.
- Brainstormed, spec'd, and planned via the standard workflow; implemented via subagent-driven development across two independently-reviewed tasks, plus a final whole-branch review (opus, READY with non-blocking notes). Two optional test-coverage gaps it flagged (both-windows-low, missing-percentage) were closed directly.
- The complete non-UI suite passed 257 tests with zero failures (167 core, 90 app); the privacy gate passed.
- Live-verified with the existing `signals` UI-test fixture (which already drives Codex's allowance below the 10% threshold on both windows) via direct accessibility-API screenshot verification: both Codex captions rendered the warning triangle and orange text, bar/pill colors stayed Codex blue.
- Both release gate variables were confirmed with the owner in chat before use, naming `AGENTICGLOW_NAME_CLEARED` and `AGENTICGLOW_RELEASE_BUILD_APPROVED` explicitly.
- Signed universal `arm64`/`x86_64` build passed strict code-signature checks. Apple accepted notarization submission `05999765-8e15-49fe-ab08-acf86e60bf30`; the DMG was stapled and validated, and Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- Released DMG SHA-256 `2f319a019c2281c74bec8f54d4b9ce121dffff30bbbcb0b6656431f8155c0983`; the asset downloaded back from the GitHub release matched the checksum, staple validation, and Gatekeeper assessment.
- `Cask/agenticglow.rb` was regenerated with the 0.4.11 checksum (main commit `e10cab8`) and pushed to the official tap `FuturisticXx/homebrew-agenticglow` (tap commit `a1c2a7b`).
- The installed `/Applications` app was replaced with the notarized 0.4.11 build, relaunched, and confirmed running with a valid Gatekeeper-accepted signature.

Public release 0.5.0 evidence recorded 2026-07-16:

- Released from commit `ce27d2d` (tag `v0.5.0`): the session card redesign (unified icon/color mapping between the row and menu bar, an inferred `.failed` state distinct from a clean disconnect, per-action tool-category icons, a live pulse on actively-working rows, elapsed time exposed to VoiceOver, an expand-to-detail tier), a code-review fix pass on that work, and a fix for Codex's usage window sometimes showing a confusing "Current, 152h" label instead of "Weekly" when Codex reports its weekly limit as the primary window.
- The full suite passed on the release commit: 310 tests (180 core, 6 event, 124 app) with zero failures; the privacy gate passed.
- Both release gate variables were confirmed with the owner in chat before use, naming `AGENTICGLOW_NAME_CLEARED` and `AGENTICGLOW_RELEASE_BUILD_APPROVED` explicitly.
- Signed universal `arm64`/`x86_64` build passed strict code-signature checks. Apple accepted notarization submission `00d3f3b2-e22d-4d14-bc9f-3fcddba06e97`; the DMG was stapled and validated, and Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- Released DMG SHA-256 `b2d5bfacd4fdf78c72e9e10463b9d894026d9ec00152cc19b50b6bb19163fbdf`; the asset downloaded back from the GitHub release matched the checksum, staple validation, and Gatekeeper assessment.
- `Cask/agenticglow.rb` was regenerated with the 0.5.0 checksum (main commit `27e439c`) and pushed to the official tap `FuturisticXx/homebrew-agenticglow` (tap commit `d069e2c`).

Public release 0.5.1 evidence recorded 2026-07-17:

- Released from commit `29b1996` (tag `v0.5.1`): the low-allowance warning caption no longer uses a single bright orange for both the icon and text. The exclamation triangle is now a fixed red; the caption text takes the provider's own accent color (Codex blue, Claude orange) instead, matching the bars above it.
- The full suite passed on the release commit: 310 tests (180 core, 6 event, 124 app) with zero failures; the privacy gate passed.
- Both release gate variables were confirmed with the owner in chat before use, naming `AGENTICGLOW_NAME_CLEARED` and `AGENTICGLOW_RELEASE_BUILD_APPROVED` explicitly.
- Signed universal `arm64`/`x86_64` build passed strict code-signature checks. Apple accepted notarization submission `26a4236b-1ba6-465d-adc1-5c828765c349`; the DMG was stapled and validated, and Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- Released DMG SHA-256 `36240e1f599c9f916181b957ad3bd3cf25744d89a067c48b2593dbf26c2b5f57`; the asset downloaded back from the GitHub release matched the checksum, staple validation, and Gatekeeper assessment.
- `Cask/agenticglow.rb` was regenerated with the 0.5.1 checksum (main commit `a611cff`) and pushed to the official tap `FuturisticXx/homebrew-agenticglow` (tap commit `10d3167`).
- The running `/Applications/AgenticGlow.app` was quit, replaced with the notarized 0.5.1 build, and relaunched; version, strict signature, and Gatekeeper all verified post-install.

Public release 0.5.2 evidence recorded 2026-07-17:

- Released from commit `984ffda` (tag `v0.5.2`): clicking a Codex session now asks Codex itself to raise its matching window (one-time, Codex-only Automation permission, not system-wide Accessibility), falling back to today's generic activation if declined or if no matching window is open; thinking sessions (Claude and Codex) show a brain icon instead of a sparkle, with the same pulse animation. Both changes were verified live by the owner on a local signed test build before this release.
- The full suite passed on the release commit: 312 tests (188 core, 124 app) with zero failures; the privacy gate passed.
- Both release gate variables were confirmed with the owner in chat before use, naming `AGENTICGLOW_NAME_CLEARED` and `AGENTICGLOW_RELEASE_BUILD_APPROVED` explicitly.
- Signed universal `arm64`/`x86_64` build passed strict code-signature checks. Apple accepted notarization submission `a159df04-6357-44cb-a4d7-0eb6017891cf`; the DMG was stapled and validated, and Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- Released DMG SHA-256 `d3a7e485b7e6f56252726dc3485f8f35fe52b6893f39e6705e5f9c59fe475840`; the asset downloaded back from the GitHub release matched the checksum, staple validation, and Gatekeeper assessment.
- `Cask/agenticglow.rb` was regenerated with the 0.5.2 checksum (main commit `796cab0`) and pushed to the official tap `FuturisticXx/homebrew-agenticglow` (tap commit `5c8c568`).
- The running `/Applications/AgenticGlow.app` was quit, replaced with the notarized 0.5.2 build, and relaunched; version, strict signature, and Gatekeeper all verified post-install.

## Current Goal

Maintain the public AgenticGlow release and graduate its Cask from the official AgenticGlow tap to `homebrew/homebrew-cask` when Homebrew's notability threshold is met.

Next unblocked work:

1. Monitor v0.4.7 and submit the existing Cask to `homebrew/homebrew-cask` once AgenticGlow qualifies under Homebrew's published notability policy.

## Legal and Branding

- [ ] **Trademark search completed** (date: ________)
  - Search USPTO for "AgenticGlow" and similar marks
  - Search App Store for similar app names
  - Document any conflicts or clearance results
  - 2026-07-03 practical screen found no exact-name listing, but similar Glow branding exists in agentic AI software; formal clearance remains required

- [x] **Marketplace availability confirmed** (date: 2026-07-05)
  - GitHub repository available: https://github.com/FuturisticXx/AgenticGlow
  - GitHub organization available (if applicable)
  - Homebrew cask name available: `agenticglow`
  - Document any conflicts or reservation confirmations
  - Public GitHub repository and official AgenticGlow Homebrew tap are live; no exact conflicting Homebrew Cask token was found

- [ ] **Domain and social handles secured** (date: ________)
  - Domain decision: ________ (registered or decision not to register)
  - Twitter/X handle: ________
  - Mastodon handle: ________
  - Document handle availability or reservation
  - 2026-07-03 preflight: `.com` is registered to another party; `.app`, `.dev`, and `.io` had no confirmed registration; no social handles were reserved

## User Approval

- [x] **User approval to publish obtained** (date: 2026-07-05)
  - User has reviewed the release plan
  - User has approved the version number
  - User has approved the release notes
  - Document approval method (email, chat, etc.)
  - 2026-07-05 active release goal explicitly authorized release readiness, publication, and Homebrew distribution

## Technical Requirements

- [x] **Developer ID signing identity configured locally** (date: 2026-07-03)
  - `DEVELOPER_ID_APPLICATION` environment variable set
  - Certificate valid and not expired
  - GitHub secret `DEVELOPER_ID_CERTIFICATE_BASE64` configured for workflow release builds, if using GitHub Actions
  - GitHub secret `DEVELOPER_ID_CERTIFICATE_PASSWORD` configured for workflow release builds, if using GitHub Actions
  - GitHub secret `AGENTICGLOW_RELEASE_KEYCHAIN_PASSWORD` configured for workflow release builds, if using GitHub Actions
  - Certificate: `Developer ID Application: John Wright (Z52AX2BH7T)`
  - SHA-256 fingerprint: `E8:1A:DD:DB:DF:1F:B1:FC:5C:49:EB:04:62:0B:37:4A:8F:CB:B3:75:15:19:9A:0D:DE:11:26:11:8E:49:45:60`
  - Valid from 2026-07-03 23:58:58 CDT through 2031-07-04 23:58:57 CDT
  - GitHub certificate export secrets configured 2026-07-04

- [x] **Notary profile configured** (date: 2026-07-04)
  - `NOTARY_PROFILE` environment variable set
  - Apple Developer notary service access confirmed
  - GitHub secrets `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD` configured for workflow release builds, if using GitHub Actions
  - Profile: `agenticglow-notary`
  - `notarytool history` authenticated successfully
  - GitHub secrets `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD` configured

- [x] **Privacy review completed** (date: 2026-07-03)
  - `Scripts/verify-privacy.sh` passes
  - Privacy contract in `docs/privacy.md` reviewed
  - No sensitive data stored or transmitted by the app itself; opt-in update checks contact GitHub Releases only
  - Provider allowance access remains opt-in, and Codex allowance is mediated by the installed Codex app-server
  - Findings: passed automated privacy contract verification

- [x] **Accessibility review completed** (date: 2026-07-05)
  - VoiceOver navigation tested
  - Reduce motion preference respected
  - Timer text hidden from accessibility
  - Document accessibility test results
  - Live accessibility tree exposed setup headings, provider status, actions, privacy explanation, and completion guidance
  - Light appearance was inspected previously; Dark appearance was inspected from the installed notarized app
  - Reduce-motion and stable spoken-label tests passed; decorative timer elements remain hidden from accessibility

## Build Verification

- [x] **Unsigned universal Release build verified** (date: 2026-07-03)
  - Release build passed for `arm64` and `x86_64`
  - Code signing disabled for local verification
  - This does not replace signed DMG, notarization, or Gatekeeper verification

- [x] **Signed and notarized DMG build verified locally** (date: 2026-07-12)
  - DMG builds successfully with code signing
  - DMG installs correctly on clean macOS 14.0+ system
  - App launches and functions correctly
  - Versions 0.1.0 and 0.1.1 built as universal `arm64` and `x86_64`
  - Notarization submission `ea62125b-5c96-4b32-8692-4d8f53c14d77` accepted
  - Stapler validation and Gatekeeper assessment passed for the app and DMG
  - Fresh DMG installation and launch passed; Homebrew install, uninstall, reinstall, and launch passed
  - v0.4.7 notarization, signature, staple, Gatekeeper, downloaded-asset checksum, installation, and relaunch checks passed

- [x] **Homebrew cask verified** (date: 2026-07-12)
  - Cask formula builds successfully
  - `brew install --cask FuturisticXx/agenticglow/agenticglow` installs correctly
  - App launches and functions correctly after install
  - Document cask version and test system
  - Version 0.1.1 install, launch, uninstall, integration cleanup, reinstall, and relaunch passed from the public tap
  - Version 0.4.7 upgraded through the public tap, launched, and passed installed signature and Gatekeeper verification

## Release Gates

Before running the release build, set the following environment variables:

```bash
export AGENTICGLOW_NAME_CLEARED=1
export AGENTICGLOW_RELEASE_BUILD_APPROVED=1
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"
export NOTARY_PROFILE="your-notary-profile"
```

Then verify:

```bash
Scripts/verify-release-gates.sh
```

## Post-Release

- [x] **GitHub release published** (date: 2026-07-17, latest: v0.5.2)
  - v0.5.2 published from commit `984ffda`
  - Apple notarization submission `a159df04-6357-44cb-a4d7-0eb6017891cf` accepted
  - Published DMG SHA-256: `d3a7e485b7e6f56252726dc3485f8f35fe52b6893f39e6705e5f9c59fe475840`
  - Downloaded release asset passed checksum comparison, staple validation, and Gatekeeper assessment
  - Release notes document the Codex window-raise fix and the brain icon for thinking sessions

- [x] **Cask updated in the official tap** (date: 2026-07-17, version 0.5.2)
  - Official tap updated to v0.5.2 at commit `5c8c568`
  - `Cask/agenticglow.rb` regenerated with the v0.5.1 checksum and pushed on main (`a611cff`)
  - The running `/Applications/AgenticGlow.app` was quit, replaced with the notarized 0.5.1 build, and relaunched; version, strict signature, and Gatekeeper all verified post-install

- [ ] **Homebrew cask submitted upstream** (date: ________)
  - PR submitted to homebrew/homebrew-cask
  - PR merged and cask available
  - Document PR number
  - Official AgenticGlow tap published and verified: `https://github.com/FuturisticXx/homebrew-agenticglow`
  - Upstream PR deferred because Homebrew rejects self-submitted apps below 90 forks, 90 watchers, or 225 stars

- [ ] **Announcement posted** (date: ________)
  - Social media announcement posted
  - Documentation updated if needed
  - Document announcement channels
