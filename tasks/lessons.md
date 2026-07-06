# Lessons

Rules learned from real mistakes in this project. Read in full at session start. Add a new entry after any correction from John.

## CI scripts must only use tools preinstalled on GitHub runners (2026-07-05)

**What happened:** `Scripts/verify-privacy.sh` used `rg` (ripgrep). It worked locally because ripgrep is installed on John's Mac via Homebrew, but GitHub's macOS runners are clean machines without it. Every push failed the CI `test` job with `rg: command not found` (exit 127), generating a failure email per push.

**Rules:**
- Any script that runs in CI must use only built-in tools: `grep`, `sed`, `awk`, `find`, `bash`, `git`, `curl`, `python3`, `xcodebuild`. No Homebrew-installed tools (`rg`, `fd`, `jq` is preinstalled on GitHub runners but verify anything else) unless the workflow explicitly installs them first.
- `grep` equivalents for ripgrep: `rg -q '\bword\b'` becomes `grep -qw word`; alternation `a|b` needs `grep -E`; fixed strings use `grep -F`; directory scans need `grep -r`.
- Exit code 127 in a CI log means "command not found." Check for missing tools before debugging anything else.
- Before adding a new CI step, ask: does this command exist on a fresh macOS runner?

## Keep GitHub Actions on current major versions (2026-07-05)

`actions/checkout@v4` triggered Node deprecation warnings on every run. Bumped to `@v5` in both `ci.yml` and `release.yml`. When a CI annotation warns about a deprecated action or runtime, bump it promptly; warnings become failures when GitHub removes the old runtime.

## Show elapsed seconds below one minute (2026-07-05)

John prefers exact elapsed seconds for active sessions under one minute. Display `54s`, for example, instead of `<1m`.

## Ambient animation must be visibly alive (2026-07-05)

The first popover aura drifted at 70 seconds per revolution and John reported "I can't see any animations" even though pixel diffing proved it was moving. Rule: ambient motion should show a clearly noticeable change within about 5 seconds of watching, while each individual moment still looks calm. Verify by capturing frames a few seconds apart, not just by confirming the animation code runs.

## Present design options as labeled visual variants in chat (2026-07-05)

When John dislikes a look, do not guess a single replacement. Render 3 or 4 labeled variants (A, B, C, D) he can see directly in the conversation and let him pick. File attachments did not display for him; inline widgets did. Also: keep color in one element per row. He asked to remove the tinted percentage text so only the bars carry the provider color.

## Confirm which element visual feedback targets (2026-07-05)

John reported "Dark Mode is too light." I read it as the whole popover surface; he meant the glowing border colors were too bright and washed out, and he wanted the dark aura to match light mode's saturated look. The surface scrim was still wanted, but the aura was the actual complaint. Rule: when John critiques a visual property (too light, too bright, too big), name the element I think he means before implementing, or present the interpretation alongside the fix so he can redirect cheaply.

## Guard new-SDK symbols with compiler checks, not just #available (2026-07-05)

`ConcentricRectangle` (macOS 26 SDK) compiled locally on Xcode 26 but broke CI, which builds with Xcode 16.4. `if #available(macOS 26.0, *)` only guards at runtime; the symbol must also exist at compile time. Wrap any API newer than the CI toolchain's SDK in `#if compiler(>=6.2)` (or the matching version) with a fallback branch. Local green is not proof: CI's Xcode is older than the local beta.
