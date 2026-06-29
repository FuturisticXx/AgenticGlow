# Klarity Release Checklist

This checklist must be completed and documented with dated evidence before any release.

## Legal and Branding

- [ ] **Trademark search completed** (date: ________)
  - Search USPTO for "Klarity" and similar marks
  - Search App Store for similar app names
  - Document any conflicts or clearance results

- [ ] **Marketplace availability confirmed** (date: ________)
  - GitHub repository available: https://github.com/jwright0180/Klarity
  - GitHub organization available (if applicable)
  - Homebrew cask name available: `klarity`
  - Document any conflicts or reservation confirmations

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
  - Document certificate name and expiration

- [ ] **Notary profile configured** (date: ________)
  - `NOTARY_PROFILE` environment variable set
  - Apple Developer notary service access confirmed
  - Document profile name

- [ ] **Privacy review completed** (date: ________)
  - `Scripts/verify-privacy.sh` passes
  - Privacy contract in `docs/privacy.md` reviewed
  - No sensitive data stored or transmitted
  - Document review findings

- [ ] **Accessibility review completed** (date: ________)
  - VoiceOver navigation tested
  - Reduce motion preference respected
  - Timer text hidden from accessibility
  - Document accessibility test results

## Build Verification

- [ ] **DMG build verified** (date: ________)
  - DMG builds successfully with code signing
  - DMG installs correctly on clean macOS 14.0+ system
  - App launches and functions correctly
  - Document build version and test system

- [ ] **Homebrew cask verified** (date: ________)
  - Cask formula builds successfully
  - `brew install --cask klarity` installs correctly
  - App launches and functions correctly after install
  - Document cask version and test system

## Release Gates

Before running the release build, set the following environment variables:

```bash
export KLARITY_NAME_CLEARED=1
export KLARITY_RELEASE_BUILD_APPROVED=1
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
