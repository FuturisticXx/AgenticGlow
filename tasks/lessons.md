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
