# AgenticGlow Release Checklist

This checklist must be completed and documented with dated evidence before any release.

## Current Private RC Evidence

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

## Current Goal

Prepare AgenticGlow for a private signed release candidate without crossing public-publication gates.

Next unblocked work:

1. Keep the GitHub repo URL consistent across app update checks, generated Homebrew cask output, README links, and release documentation.
2. Decide whether the private repo remains under `FuturisticXx/AgenticGlow` or moves before public release.
3. Perform a fresh practical name-clearance screen, then set `AGENTICGLOW_NAME_CLEARED=1` only after explicit approval.
4. Configure Developer ID signing and notary credentials.
5. Build and verify a signed, notarized DMG.
6. Verify Gatekeeper launch, generated Homebrew cask, and release artifact checksums before publication.

## Legal and Branding

- [ ] **Trademark search completed** (date: ________)
  - Search USPTO for "AgenticGlow" and similar marks
  - Search App Store for similar app names
  - Document any conflicts or clearance results
  - Preliminary practical preflight found no obvious exact-name conflict; formal clearance remains required

- [ ] **Marketplace availability confirmed** (date: ________)
  - GitHub repository available: https://github.com/FuturisticXx/AgenticGlow
  - GitHub organization available (if applicable)
  - Homebrew cask name available: `agenticglow`
  - Document any conflicts or reservation confirmations
  - Preliminary Homebrew cask-list preflight found no exact `agenticglow` token; formal marketplace checks remain required

- [ ] **Domain and social handles secured** (date: ________)
  - Domain decision: ________ (registered or decision not to register)
  - Twitter/X handle: ________
  - Mastodon handle: ________
  - Document handle availability or reservation

## User Approval

- [ ] **User approval to publish obtained** (date: ________)
  - User has reviewed the release plan
  - User has approved the version number
  - User has approved the release notes
  - Document approval method (email, chat, etc.)

## Technical Requirements

- [ ] **Developer ID signing identity configured** (date: ________)
  - `DEVELOPER_ID_APPLICATION` environment variable set
  - Certificate valid and not expired
  - GitHub secret `DEVELOPER_ID_CERTIFICATE_BASE64` configured for workflow release builds, if using GitHub Actions
  - GitHub secret `DEVELOPER_ID_CERTIFICATE_PASSWORD` configured for workflow release builds, if using GitHub Actions
  - GitHub secret `AGENTICGLOW_RELEASE_KEYCHAIN_PASSWORD` configured for workflow release builds, if using GitHub Actions
  - Document certificate name and expiration

- [ ] **Notary profile configured** (date: ________)
  - `NOTARY_PROFILE` environment variable set
  - Apple Developer notary service access confirmed
  - GitHub secrets `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD` configured for workflow release builds, if using GitHub Actions
  - Document profile name

- [x] **Privacy review completed** (date: 2026-07-03)
  - `Scripts/verify-privacy.sh` passes
  - Privacy contract in `docs/privacy.md` reviewed
  - No sensitive data stored or transmitted by the app itself; opt-in update checks contact GitHub Releases only
  - Provider allowance access remains opt-in, and Codex allowance is mediated by the installed Codex app-server
  - Findings: passed automated privacy contract verification

- [ ] **Accessibility review completed** (date: partial 2026-07-03)
  - VoiceOver navigation tested
  - Reduce motion preference respected
  - Timer text hidden from accessibility
  - Document accessibility test results
  - Partial evidence: accessibility tree and Light appearance inspected; separate Dark appearance screenshot remains unverified

## Build Verification

- [x] **Unsigned universal Release build verified** (date: 2026-07-03)
  - Release build passed for `arm64` and `x86_64`
  - Code signing disabled for local verification
  - This does not replace signed DMG, notarization, or Gatekeeper verification

- [ ] **DMG build verified** (date: ________)
  - DMG builds successfully with code signing
  - DMG installs correctly on clean macOS 14.0+ system
  - App launches and functions correctly
  - Document build version and test system

- [ ] **Homebrew cask verified** (date: ________)
  - Cask formula builds successfully
  - `brew install --cask agenticglow` installs correctly
  - App launches and functions correctly after install
  - Document cask version and test system

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

- [ ] **GitHub release published** (date: ________)
  - Release notes published
  - DMG uploaded to release
  - Tag pushed to repository

- [ ] **Homebrew cask submitted** (date: ________)
  - PR submitted to homebrew/homebrew-cask
  - PR merged and cask available
  - Document PR number

- [ ] **Announcement posted** (date: ________)
  - Social media announcement posted
  - Documentation updated if needed
  - Document announcement channels
