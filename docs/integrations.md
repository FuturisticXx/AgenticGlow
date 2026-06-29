# Klarity Integrations

Klarity integrates with AI coding providers by installing hooks that emit events to the `klarity-event` helper. This document describes exactly what Klarity installs, where, and how to remove it.

## Claude Integration

### Config Path
`~/.claude/settings.json`

### Installed Events
Klarity installs hooks for the following events:
- `sessionStart`
- `sessionEnd`
- `userPromptSubmit`
- `preToolUse`
- `postToolUse`
- `notification`
- `permissionRequest`
- `stop`

### Hook Format
Each hook entry is marked with `--klarity-hook` in the command string for identification. The command executes the `klarity-event` helper with the provider, event kind, and marker flag.

### Backup
On first modification, Klarity creates a backup at:
`~/.claude/settings.json.YYYYMMDD-HHmmss.bak-klarity`

### Repair Behavior
Running repair removes any existing Klarity hooks and reinstalls all supported events. This fixes partial or corrupted installations.

### Removal Behavior
Running remove deletes only entries marked with `--klarity-hook`. All other hooks and settings are preserved.

## Codex Integration

### Config Path
`~/.codex/hooks.json`

### Installed Events
Klarity installs hooks for the following events:
- `sessionStart`
- `userPromptSubmit`
- `preToolUse`
- `postToolUse`
- `permissionRequest`
- `stop`

### Hook Format
Each hook entry is marked with `--klarity-hook` in the command string for identification. The command executes the `klarity-event` helper with the provider, event kind, and marker flag.

### Backup
On first modification, Klarity creates a backup at:
`~/.codex/hooks.json.YYYYMMDD-HHmmss.bak-klarity`

### Repair Behavior
Running repair removes any existing Klarity hooks and reinstalls all supported events. This fixes partial or corrupted installations.

### Removal Behavior
Running remove deletes only entries marked with `--klarity-hook`. All other hooks and settings are preserved.

## Helper Installation

### Destination Path
`~/Library/Application Support/Klarity/bin/klarity-event`

### Permissions
The helper binary is installed with `0o755` permissions (owner read/write/execute, group/others read/execute).

### Directory Permissions
The parent directory is created with `0o700` permissions (owner read/write/execute only).

### Repair Behavior
Running repair copies the helper from the embedded bundle to the destination, replacing the existing file atomically.

### Removal Behavior
Running remove deletes the entire `~/Library/Application Support/Klarity/bin` directory.

## Clean Removal

To completely remove Klarity without running the app:

```bash
# Remove integrations
open -a Klarity.app --args --remove-integrations

# Or manually delete the helper directory
rm -rf ~/Library/Application\ Support/Klarity/bin
```

This removes only Klarity-marked hooks and Klarity-owned files. Your provider configurations remain intact.
