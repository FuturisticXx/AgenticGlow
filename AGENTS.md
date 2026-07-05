# AgenticGlow Agent Instructions

Before doing anything else, read `tasks/lessons.md` in full. It contains rules learned from real mistakes in this project, and they are binding.

Key standing rules:

- CI scripts (`Scripts/*.sh` run by `.github/workflows/`) must only use tools preinstalled on GitHub's macOS runners. No Homebrew-installed tools like `rg` or `fd` unless the workflow installs them first. Prefer `grep`, `sed`, `awk`, and other built-ins.
- After changing any CI workflow or script, push and confirm the GitHub Actions run goes green before calling the task complete.
- Log completed work in `gotdone.md` after every commit and push.
- Never use em dashes in prose or user-facing strings. Hyphens in compound words are fine.
