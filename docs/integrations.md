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
hook can launch and AgenticGlow can receive a live session event. Do not recreate
an obsolete path or edit Codex private application state as a workaround.

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
