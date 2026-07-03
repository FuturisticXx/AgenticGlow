# AgenticGlow Rename Finalization Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Do not dispatch subagents unless John explicitly authorizes delegation.

**Goal:** Convert the completed AgenticGlow rename into one reviewed, reproducible, fully verified local commit without pushing, merging, tagging, signing, notarizing, publishing, or releasing.

**Architecture:** Treat the current dirty tree as the rename candidate and the checked-in release-baseline commit as the immutable comparison baseline. Stage the complete candidate early so Git can identify file moves as renames, audit the small set of actual content changes, regenerate the Xcode project deterministically, run one complete verification ladder, and commit only after every gate passes.

**Tech Stack:** macOS 14+, Swift, SwiftUI, AppKit, XCTest/XCUITest, XcodeGen, Xcode 26.6, Bash, Git.

## Global Constraints

- Work only in the current release-baseline worktree and keep its current branch unchanged.
- Preserve the separate older dirty worktree and its branch unchanged.
- Preserve all current AgenticGlow rename work; do not reset, clean, checkout, merge, cherry-pick, or rebase.
- Zero case-insensitive legacy product references may remain in tracked project content.
- Do not add features, redesign UI, refactor behavior, update dependencies, or clean unrelated code.
- Do not set release approval variables or weaken privacy, signing, notarization, or publication gates.
- Stop at one local commit. Do not push, merge, tag, sign, notarize, publish, or release.

---

### Task 1: Audit and stage the rename candidate

**Files:**
- Review: `project.yml`
- Review: `.github/workflows/ci.yml`
- Review: `.github/workflows/release.yml`
- Review: `Config/AgenticGlow-Info.plist`
- Review: `Config/AgenticGlow.entitlements`
- Review: `Sources/AgenticGlowApp/`
- Review: `Sources/AgenticGlowCore/`
- Review: `Sources/AgenticGlowEvent/`
- Review: `Tests/AgenticGlowAppTests/`
- Review: `Tests/AgenticGlowCoreTests/`
- Review: `Tests/AgenticGlowEventTests/`
- Review: `Tests/AgenticGlowUITests/`
- Review: `Scripts/`
- Review: `README.md`
- Review: `docs/`
- Add: `docs/superpowers/plans/2026-07-02-agenticglow-rename-finalization.md`

**Interfaces:**
- Consumes: the current dirty rename candidate and `HEAD` as the pre-rename baseline.
- Produces: an intentionally staged rename whose real content changes can be reviewed with Git rename detection.

- [ ] **Step 1: Confirm the worktree and branch boundary**

Run:

```bash
repo_root="$(git rev-parse --show-toplevel)"
test "$(pwd)" = "$repo_root"
test -n "$(git branch --show-current)"
git worktree list --porcelain
```

Expected: both `test` commands succeed; the current release-baseline worktree and separate older worktree remain on their original branches.

- [ ] **Step 2: Reject legacy names and generated build artifacts before staging**

Run:

```bash
legacy_pattern="$(printf '\x6b\x6c\x61\x72\x69\x74\x79\x7c\x73\x65\x73\x73\x69\x6f\x6e\x6c\x65\x74')"
if rg -n -i "$legacy_pattern" . \
  --hidden \
  -g '!.git' \
  -g '!.git/**' \
  -g '!build/**' \
  -g '!.build/**'; then
  echo "Legacy product reference found" >&2
  exit 1
fi

git status --short | rg '(^|/)(build|DerivedData|\.build)/' && exit 1 || true
```

Expected: no legacy-name output and no build artifacts in Git status.

- [ ] **Step 3: Stage the complete candidate so Git can identify moves**

Run:

```bash
git add -A
git status --short
git diff --cached --find-renames=90% --summary
```

Expected: AgenticGlow paths are staged; old product paths appear primarily as renames rather than unrelated delete/add pairs.

- [ ] **Step 4: Verify the staged path allowlist**

Run:

```bash
git diff --cached --name-only | awk '
  /^(\.codex\/environments\/environment\.toml|\.github\/workflows\/|Config\/|Design\/|[^\/]+\.xcodeproj\/|Sources\/|Tests\/|Scripts\/|script\/|docs\/|README\.md$|LICENSE$|project\.yml$)/ { next }
  { print; unexpected = 1 }
  END { exit unexpected }
'
```

Expected: no output. Every staged path belongs to the rename, its tests, documentation, CI, or release tooling.

- [ ] **Step 5: Review actual content changes rather than file movement noise**

Run:

```bash
git diff --cached --check
git diff --cached --find-renames=90% --stat
git diff --cached --find-renames=90% -- \
  project.yml \
  README.md \
  LICENSE \
  .codex/environments/environment.toml \
  .github/workflows/ci.yml \
  .github/workflows/release.yml \
  Config \
  Scripts \
  script \
  docs \
  Tests/Fixtures \
  Tests/TestSupport
```

Expected: `git diff --check` succeeds. Reviewed hunks change product identity, paths, commands, environment variables, URLs, and documentation only; privacy and release gates remain intact.

---

### Task 2: Prove XcodeGen determinism and project integrity

**Files:**
- Source of truth: `project.yml`
- Generated and tracked: `AgenticGlow.xcodeproj/`

**Interfaces:**
- Consumes: the staged `project.yml` and `AgenticGlow.xcodeproj` candidate.
- Produces: byte-stable generated Xcode project output with valid AgenticGlow schemes and targets.

- [ ] **Step 1: Capture the staged generated-project tree**

Run:

```bash
before="$(find AgenticGlow.xcodeproj -type f ! -name '._*' -print0 | sort -z | xargs -0 shasum -a 256)"
xcodegen generate
after="$(find AgenticGlow.xcodeproj -type f ! -name '._*' -print0 | sort -z | xargs -0 shasum -a 256)"
test "$before" = "$after"
git diff --exit-code -- AgenticGlow.xcodeproj
```

Expected: hashes match and the generated project has no unstaged difference from the staged candidate.

- [ ] **Step 2: Generate a second time to reject order-dependent output**

Run:

```bash
second_before="$(find AgenticGlow.xcodeproj -type f ! -name '._*' -print0 | sort -z | xargs -0 shasum -a 256)"
xcodegen generate
second_after="$(find AgenticGlow.xcodeproj -type f ! -name '._*' -print0 | sort -z | xargs -0 shasum -a 256)"
test "$second_before" = "$second_after"
git diff --exit-code -- AgenticGlow.xcodeproj
```

Expected: the second generation is also byte-stable.

- [ ] **Step 3: Confirm project targets and shared schemes**

Run:

```bash
xcodebuild -list -project AgenticGlow.xcodeproj
test -f AgenticGlow.xcodeproj/xcshareddata/xcschemes/AgenticGlow.xcscheme
test -f AgenticGlow.xcodeproj/xcshareddata/xcschemes/AgenticGlowEvent.xcscheme
```

Expected: `AgenticGlow`, `AgenticGlowCore`, `AgenticGlowEvent`, and all AgenticGlow test targets are listed; both shared schemes exist.

---

### Task 3: Run the complete verification ladder once

**Files:**
- Test: `Tests/AgenticGlowAppTests/`
- Test: `Tests/AgenticGlowCoreTests/`
- Test: `Tests/AgenticGlowEventTests/`
- Test: `Tests/AgenticGlowUITests/`
- Verify: `Scripts/verify-privacy.sh`
- Verify: `Scripts/verify-standalone-helper.sh`

**Interfaces:**
- Consumes: deterministic AgenticGlow project output.
- Produces: current test, privacy, helper, and universal-build evidence from the exact staged candidate.

- [ ] **Step 1: Validate shell syntax before expensive builds**

Run:

```bash
bash -n Scripts/*.sh script/build_and_run.sh
```

Expected: exit status 0 with no output.

- [ ] **Step 2: Run all unit, integration, and UI tests**

Run:

```bash
rm -rf /tmp/AgenticGlowDerivedData
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AgenticGlowDerivedData \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  'CODE_SIGN_IDENTITY=Apple Development: John Wright (8W3424FG79)' \
  DEVELOPMENT_TEAM=Z52AX2BH7T \
  ENABLE_HARDENED_RUNTIME=NO
```

Expected: `** TEST SUCCEEDED **` and 129 tests pass, including `AgenticGlowUITests`. This host has Developer Tools mode disabled, so only temporary Debug test products in `/tmp` are development-signed to satisfy Gatekeeper; the Release build remains unsigned by Xcode.

- [ ] **Step 3: Verify the privacy contract and embedded helper**

Run:

```bash
Scripts/verify-privacy.sh
Scripts/verify-standalone-helper.sh \
  /tmp/AgenticGlowDerivedData/Build/Products/Debug/AgenticGlow.app/Contents/Resources/bin/agenticglow-event
```

Expected: both commands exit 0; the copied helper writes exactly one sanitized session file without bundled-framework dependencies.

- [ ] **Step 4: Build the universal unsigned Release app**

Run:

```bash
rm -rf build/ReleaseDerivedData
xcodebuild build \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -configuration Release \
  -derivedDataPath build/ReleaseDerivedData \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Verify both required architectures in the app and helper**

Run:

```bash
app='build/ReleaseDerivedData/Build/Products/Release/AgenticGlow.app'
helper="$app/Contents/Resources/bin/agenticglow-event"
app_archs="$(lipo -archs "$app/Contents/MacOS/AgenticGlow")"
helper_archs="$(lipo -archs "$helper")"
[[ "$app_archs" == *arm64* && "$app_archs" == *x86_64* ]]
[[ "$helper_archs" == *arm64* && "$helper_archs" == *x86_64* ]]
printf 'App: %s\nHelper: %s\n' "$app_archs" "$helper_archs"
```

Expected: both lines contain `arm64` and `x86_64`.

---

### Task 4: Final gate and local commit

**Files:**
- Commit: all intentionally staged files from Tasks 1 through 3.

**Interfaces:**
- Consumes: a fully staged candidate with current passing verification evidence.
- Produces: one local commit on the current release-baseline branch, with no external publication or repository mutation.

- [ ] **Step 1: Re-run cheap final invariants after all generators and builds**

Run:

```bash
git diff --check
git diff --cached --check
git diff --exit-code -- AgenticGlow.xcodeproj

legacy_pattern="$(printf '\x6b\x6c\x61\x72\x69\x74\x79\x7c\x73\x65\x73\x73\x69\x6f\x6e\x6c\x65\x74')"
if rg -n -i "$legacy_pattern" . \
  --hidden \
  -g '!.git' \
  -g '!.git/**' \
  -g '!build/**' \
  -g '!.build/**'; then
  echo "Legacy product reference found" >&2
  exit 1
fi
```

Expected: all commands succeed and the legacy scan prints nothing.

- [ ] **Step 2: Confirm nothing became unstaged during verification**

Run:

```bash
git status --short
test -z "$(git diff --name-only)"
git diff --cached --find-renames=90% --stat
```

Expected: every intended source change is staged; ignored build output is absent from status; there are no unstaged tracked changes.

- [ ] **Step 3: Create one intentional local commit**

Run:

```bash
git commit -m "refactor: rename app to AgenticGlow"
```

Expected: one commit is created on the current release-baseline branch.

- [ ] **Step 4: Verify the post-commit boundary**

Run:

```bash
git status --short --branch
git show --stat --oneline --summary HEAD
git branch --show-current
```

Expected: the branch is unchanged; the working tree is clean; no push, merge, tag, signing, notarization, publication, or release has occurred.

## Completion Gate

This plan is complete only when:

- The rename audit shows no unintended behavioral or privacy changes.
- Zero case-insensitive legacy product references remain in tracked project content.
- XcodeGen produces byte-identical output twice.
- All 129 tests pass, including UI tests.
- Privacy and standalone-helper checks pass.
- The unsigned Release app and helper each contain `arm64` and `x86_64`.
- One local commit exists on the current release-baseline branch.
- Nothing has been pushed, merged, tagged, signed, notarized, published, or released.
