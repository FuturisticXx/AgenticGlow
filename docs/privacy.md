# AgenticGlow Privacy

AgenticGlow runs locally on your Mac. It has no account system, backend, analytics,
telemetry, advertising, cloud sync, remote monitoring, or uploaded crash reports.

## Stored session fields

- `schemaVersion`
- `provider`
- `surface`
- `sessionID`
- `turnID`
- `phase`
- `label`
- `toolCategory`
- `projectName`
- `workingDirectory`
- `sourceBundleID`
- `sourceProcessID`
- `sourceProcessStartedAt`
- `turnStartedAt`
- `updatedAt`

AgenticGlow does not store prompts, responses, assistant messages, commands, tool
arguments, tool responses, transcript contents, or file contents.

## Network requests

AgenticGlow makes no network request by default. A manual update check, or an
automatic update check explicitly enabled by the user, requests only the latest
release metadata from GitHub's public Releases API.
