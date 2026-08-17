# AgenticGlow Integrations

AgenticGlow integrates with AI coding providers by installing hooks that emit events to the `agenticglow-event` helper. This document describes exactly what AgenticGlow installs, where, and how to remove it.

## Claude Integration

### Config Path
`~/.claude/settings.json`

### Installed Events
AgenticGlow installs hooks for the following events:
- `sessionStart`
- `sessionEnd`
- `userPromptSubmit`
- `preToolUse`
- `postToolUse`
- `notification`
- `permissionRequest`
- `stop`

### Hook Format
Each hook entry is marked with `--agenticglow-hook` in the command string for identification. The command executes the `agenticglow-event` helper with the provider, event kind, and marker flag.

### Backup
On first modification, AgenticGlow creates a backup at:
`~/.claude/settings.json.YYYYMMDD-HHmmss.bak-agenticglow`

### Repair Behavior
Running repair removes any existing AgenticGlow hooks and reinstalls all supported events. This fixes partial or corrupted installations.

### Removal Behavior
Running remove deletes only entries marked with `--agenticglow-hook`. All other hooks and settings are preserved.

## Codex Integration

### Config Path
`~/.codex/hooks.json`

### Installed Events
AgenticGlow installs hooks for the following events:
- `sessionStart`
- `userPromptSubmit`
- `preToolUse`
- `postToolUse`
- `permissionRequest`
- `stop`

### Hook Format
Each hook entry is marked with `--agenticglow-hook` in the command string for identification. The command executes the `agenticglow-event` helper with the provider, event kind, and marker flag.

### Backup
On first modification, AgenticGlow creates a backup at:
`~/.codex/hooks.json.YYYYMMDD-HHmmss.bak-agenticglow`

### Repair Behavior
Running repair removes any existing AgenticGlow hooks and reinstalls all supported events. This fixes partial or corrupted installations.

### Removal Behavior
Running remove deletes only entries marked with `--agenticglow-hook`. All other hooks and settings are preserved.

### Workspace Changes
Codex launches hooks from the task's working directory. If a project directory is
renamed, moved, or deleted, reopen the task from the current project path so the
hook can launch and AgenticGlow can receive detailed live phase events. AgenticGlow
also uses Codex's read-only `thread/list` app-server method as a presence fallback,
so a recent session remains visible even while its hook working directory is
invalid. Do not recreate an obsolete path or edit Codex private application state
as a workaround.

### Read-only Session Presence Fallback
AgenticGlow asks the installed local Codex app-server for recent thread metadata
every 15 seconds. It requests state-database metadata only and reads the thread ID,
working directory, update time, status, and source type. It does not request or
decode thread names, prompt previews, messages, or transcript content. Discovered
sessions are retained for up to four hours and merged with hook events by the same
hashed session identifier. A current hook event remains authoritative because it
contains the detailed tool, permission, and completion phases that the fallback
cannot provide.

### Config Is Cached at Process Startup
Codex's `app-server` process reads `~/.codex/hooks.json` once, at its own launch,
and holds it in memory for the life of the process. It does not hot-reload on
file change. After running Install or Repair for Codex, fully quit the ChatGPT
app (confirm no `codex` / `Codex Framework` / `ChatGPT` processes remain) and
relaunch it before new hook events will fire. Restarting AgenticGlow or closing
individual session windows is not sufficient. Codex will also prompt to re-trust
the hooks (`/hooks`) after they change; accept the AgenticGlow entries.

### One Process Backs Every Session
The same `app-server` process reports `sourceProcessID` for every Codex
conversation you have open or have had open that day; it does not exit between
tasks. This means "the source process is alive" cannot detect a single session
whose turn finished without its `stop` event reaching AgenticGlow. `SessionResolver`
falls back to a 30-minute staleness cutoff for `thinking`/`usingTool` sessions
(`SessionResolver.staleActiveDuration`) so an orphaned turn rolls over to Idle
instead of displaying as active indefinitely. Pending permission prompts are
exempt, since those can legitimately wait a long time for you.

## Helper Installation

### Destination Path
`~/Library/Application Support/AgenticGlow/bin/agenticglow-event`

### Permissions
The helper binary is installed with `0o755` permissions (owner read/write/execute, group/others read/execute).

### Directory Permissions
The parent directory is created with `0o700` permissions (owner read/write/execute only).

### Repair Behavior
Running repair copies the helper from the embedded bundle to the destination, replacing the existing file atomically.

### Removal Behavior
Running remove deletes the entire `~/Library/Application Support/AgenticGlow/bin` directory.

## Clean Removal

To completely remove AgenticGlow without running the app:

```bash
# Remove integrations
open -a AgenticGlow.app --args --remove-integrations

# Or manually delete the helper directory
rm -rf ~/Library/Application\ Support/AgenticGlow/bin
```

This removes only AgenticGlow-marked hooks and AgenticGlow-owned files. Your provider configurations remain intact.

## Cursor Integration

### Config Path
`~/.cursor/hooks.json`

AgenticGlow installs **user-level** Cursor hooks only. It does not write project
hooks into a repository's `.cursor/hooks.json`, because those files are often
committed to git.

Verified against Cursor 3.16.17 (`/Applications/Cursor.app`, bundle ID
`com.todesktop.230313mzl4w4u92`). Cursor documents this interface at
[cursor.com/docs/hooks](https://cursor.com/docs/hooks).

### Installed Events
AgenticGlow installs observe-only hooks for:
- `sessionStart`
- `sessionEnd`
- `beforeSubmitPrompt`
- `preToolUse`
- `postToolUse`
- `postToolUseFailure`
- `stop`

Each command calls `agenticglow-event` with provider `cursor` and the matching
AgenticGlow event kind. Hooks are fail-open: they never set `failClosed`, never
return a deny/ask permission, and never write a `followup_message`. A helper
failure cannot block the Cursor agent.

### What AgenticGlow Reads
Cursor's hook stdin JSON uses `conversation_id` as the stable session identity
and `workspace_roots` for the project path. AgenticGlow maps those onto the
shared session model, plus `generation_id` as the turn identifier, `tool_name`
when present, `model` / `model_id` when present, and `stop.status` for
completion versus failure.

It does **not** store `prompt`, `command`, `tool_input`, `tool_output`,
`user_email`, `transcript_path`, `error_message`, or transcript contents.

### Reload Behavior
Cursor watches `hooks.json` and reloads it automatically. After Install or
Repair for Cursor, you do not need to quit Cursor. If hooks still do not fire,
check Cursor Settings → Hooks and confirm the workspace is trusted.

### Known Limitations
- Cursor does not document `Notification` or `PermissionRequest` hooks.
  AgenticGlow therefore cannot detect Cursor's own approval dialogs or
  "waiting for you" prompts. Permission attention for Cursor is unsupported.
- User-level hooks do not run in Cursor Cloud Agents. Cloud and dashboard
  background agents are not visible through this integration.
- Cursor CLI hook coverage is partial. Some CLI turns may only report a subset
  of events.
- Cursor does not document a local programmatic allowance, plan-usage, or
  spend API. AgenticGlow does not scrape the Cursor dashboard and does not
  show Cursor usage bars.
- Tab completion hooks are not installed. They are too frequent and are not
  agent sessions.
- Subagent start/stop hooks are not installed, so Task subagents stay folded
  into the parent conversation rather than appearing as extra sessions.
- Enabling Cursor's "third-party skills" can also load Claude Code hooks.
  AgenticGlow still attributes Cursor sessions as Cursor because it installs
  native `~/.cursor/hooks.json` entries that pass `cursor` to the helper.

### Backup
On first modification, AgenticGlow creates a backup at:
`~/.cursor/hooks.json.<uuid>.bak-agenticglow`

### Repair Behavior
Running repair removes any existing AgenticGlow Cursor hooks and reinstalls
the supported events. Other hooks in the file are preserved.

### Removal Behavior
Running remove deletes only entries marked with `--agenticglow-hook`. All
other Cursor hooks and settings are preserved.

### Future Cursor Changes
If Cursor renames hook events, changes the stdin schema, or stops spawning
user-level hooks, AgenticGlow will show Cursor as installed with no live
sessions rather than guessing from UI scraping. The provider layer can gain
new fields without rewriting Codex or Claude. A deeper integration would need
Cursor to document: a permission-prompt hook, a local usage/allowance API, and
stable per-window session identity for Cloud Agents.
