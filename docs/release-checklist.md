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

## Current Goal

Prepare AgenticGlow for a private signed release candidate without crossing public-publication gates.

Next unblocked work:

1. Verify a clean-system install and Homebrew installation before any publication decision.

## Legal and Branding

- [ ] **Trademark search completed** (date: ________)
  - Search USPTO for "AgenticGlow" and similar marks
  - Search App Store for similar app names
  - Document any conflicts or clearance results
  - 2026-07-03 practical screen found no exact-name listing, but similar Glow branding exists in agentic AI software; formal clearance remains required

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
  - 2026-07-03 preflight: `.com` is registered to another party; `.app`, `.dev`, and `.io` had no confirmed registration; no social handles were reserved

## User Approval

- [ ] **User approval to publish obtained** (date: ________)
  - User has reviewed the release plan
  - User has approved the version number
  - User has approved the release notes
  - Document approval method (email, chat, etc.)
  - 2026-07-03 chat approval covers the AgenticGlow name and private release-candidate build only; public publication remains unapproved

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

- [x] **Signed and notarized DMG build verified locally** (date: 2026-07-04)
  - DMG builds successfully with code signing
  - DMG installs correctly on clean macOS 14.0+ system
  - App launches and functions correctly
  - Version 0.1.0 built as universal `arm64` and `x86_64`
  - Notarization submission `ea62125b-5c96-4b32-8692-4d8f53c14d77` accepted
  - Stapler validation and Gatekeeper assessment passed for the app and DMG
  - Clean-system installation and launch remain pending

- [ ] **Homebrew cask verified** (date: ________)
  - Cask formula builds successfully
  - `brew install --cask agenticglow` installs correctly
  - App launches and functions correctly after install
  - Document cask version and test system
  - 2026-07-04: generated cask version 0.1.0 passes Ruby syntax and contains the verified DMG SHA-256; installation remains blocked until a release URL exists

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
