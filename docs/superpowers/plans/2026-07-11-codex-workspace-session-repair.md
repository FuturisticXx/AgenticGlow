# Codex Workspace Session Repair Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the deleted Klarity workspace association with the real AgenticGlow directory and prove that a real Codex hook event appears as a live AgenticGlow session.

**Architecture:** Use the supported `codex app PATH` entry point instead of editing Codex private state. Verify the existing hook, helper, state file, current process identity, and AgenticGlow presentation as one end-to-end pipeline.

**Tech Stack:** Codex Desktop, Codex CLI 0.144.0-alpha.4, AgenticGlow hook helper, macOS process inspection

**Status:** Repair completed with supported workspace registration and a real current-process event. Resolver-level active-session evidence was verified; a separate direct popover capture was not recorded.

## Global Constraints

- Use `/Volumes/Liquid/2DaMax Development/AgenticGlow` as the canonical checkout.
- Do not recreate `/Volumes/Liquid/2DaMax Development/Klarity` as a symlink or directory.
- Do not edit Codex private SQLite databases, Electron state JSON, application binaries, or hook trust hashes.
- Do not use synthetic state as final evidence.
- Keep AgenticGlow diagnostics off after verification.
- Remove any temporary test session created during diagnosis.
- Use no em dashes in documentation or user-facing copy.

---

### Task 1: Open the canonical workspace and verify a real session event

**Files:**
- Read: `~/.codex/hooks.json`
- Read: `~/Library/Application Support/AgenticGlow/Sessions/*.json`
- Modify: `gotdone.md`

**Interfaces:**
- Consumes: supported `codex app [PATH]`, installed AgenticGlow Codex hooks, `agenticglow-event`
- Produces: a real state file whose source process matches the current Codex process and a visible AgenticGlow session row

- [x] **Step 1: Capture pre-repair evidence**

```bash
test ! -d '/Volumes/Liquid/2DaMax Development/Klarity'
test -d '/Volumes/Liquid/2DaMax Development/AgenticGlow'
ps aux | grep -E '[C]odex.*app-server|[A]genticGlow.app'
find "$HOME/Library/Application Support/AgenticGlow/Sessions" \
  -maxdepth 1 -type f -print
```

Expected: Klarity is absent, AgenticGlow exists, both applications run, and no state file represents the current Codex app-server process.

- [x] **Step 2: Open the canonical workspace through the supported Codex command**

```bash
'/Applications/ChatGPT.app/Contents/Resources/codex' app \
  '/Volumes/Liquid/2DaMax Development/AgenticGlow'
```

Expected: Codex Desktop opens or focuses AgenticGlow without a compatibility path or private-state edit.

- [x] **Step 3: Start or reopen a task under the canonical workspace**

In Codex Desktop, create or reopen a task whose displayed workspace is AgenticGlow, then send one ordinary prompt. Do not use the stale task if its environment still reports the Klarity path.

Expected: Codex runs `SessionStart` or `UserPromptSubmit` from the real AgenticGlow directory.

- [x] **Step 4: Verify a real current-process session file**

```bash
codex_pid="$(pgrep -f '/Applications/ChatGPT.app/Contents/Resources/codex.*app-server' | head -1)"
test -n "$codex_pid"
find "$HOME/Library/Application Support/AgenticGlow/Sessions" \
  -maxdepth 1 -type f -mmin -2 -print -exec sed -n '1,160p' {} \;
```

Expected: a fresh Codex event has `workingDirectory` set to AgenticGlow and `sourceProcessID` equal to `codex_pid`. It contains normalized metadata only.

- [ ] **Step 5: Verify AgenticGlow presents the real session**

Resolver-level verification passed because the event remained in `thinking` and
its recorded Codex app-server process was alive. Direct visual confirmation of
the popover row was not captured, so this presentation step remains open.

Open the AgenticGlow popover while the task is thinking or using a tool.

Expected: the summary no longer says `0 sessions`; the task row shows Codex and its current phase.

- [x] **Step 6: Confirm cleanup state**

```bash
defaults read com.twodamax.agenticglow diagnosticsEnabled
test ! -e "$HOME/Library/Application Support/AgenticGlow/Sessions/codex-sid_86ce34b9c9366ba691fe34885e3c0b7f34eff1c3209d6fd226a025b966348520.json"
git status --short --branch
```

Expected: diagnostics is `0`, the synthetic diagnostic file is absent, and only intentional repository changes remain.

- [x] **Step 7: Record factual repair evidence**

Add the corrected workspace, real event timestamp, process match, and visible result to `gotdone.md`. Do not claim the stale task was migrated unless its environment changed.

```bash
git add gotdone.md
git commit -m "docs: record Codex workspace session repair"
```

Expected: no Codex private state or session JSON is committed.
