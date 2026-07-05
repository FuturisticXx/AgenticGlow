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

Subscription allowance access is also off by default and separately controlled
for Codex and Claude. After Codex opt-in, AgenticGlow asks the installed local
`codex app-server` for the current five-hour and weekly rate-limit windows.
Codex manages its own existing sign-in. AgenticGlow never reads, copies, logs,
or stores Codex credentials or authorization headers.

Anthropic does not currently document a supported public subscription allowance
API. If the user explicitly enables the unofficial Claude connection and pastes
their full `claude.ai` Cookie request header, AgenticGlow stores that cookie only
as a generic password in macOS Keychain. It extracts the active organization and
requests the private `claude.ai` organization usage endpoint. The connection may
stop working if Anthropic changes its web API. AgenticGlow never writes the
cookie to UserDefaults, logs, session files, allowance cache files, or source.
Disabling Claude deletes both its normalized cache and Keychain cookie.

## Stored allowance fields

For each enabled provider, AgenticGlow stores only the latest normalized value:

- Provider.
- Current-window label, percentage used, percentage left, and reset time.
- Weekly percentage used, percentage left, and reset time.
- Fetch time.

Disabling a provider immediately deletes its cached allowance. AgenticGlow does
not store raw provider responses, usage history, token history, cost history,
credentials, cookies, or authorization headers. The optional Claude session
cookie is stored separately in macOS Keychain and is never part of allowance
cache data.
