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

For Codex session presence, AgenticGlow also asks the installed local
`codex app-server` for recent thread metadata. It decodes only the thread ID,
working directory, update time, status, and source type. It deliberately does
not decode or store thread names, prompt previews, messages, or transcripts.
This local fallback keeps a Codex session visible when Codex cannot launch a
hook from a task whose working directory was moved or deleted. Hook events
remain authoritative for detailed tool and permission phases when available.
The request runs only against the installed local Codex app-server and does not
add an AgenticGlow network request.

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

## Provider service status (optional)

Provider incident display is off by default. When the user enables "Show
provider incidents" in Settings, AgenticGlow fetches the public, unauthenticated
status summary for each provider when the popover opens, at most once per ten
minutes:

- Claude: `https://status.claude.com/api/v2/status.json`
- Codex: `https://status.openai.com/api/v2/status.json`

These are plain GET requests to public status pages. No cookies, credentials,
account data, or identifiers are sent. The normalized result (operational or
incident description) is held in memory only, never written to disk, and is
discarded when the toggle is turned off or the app quits.

## Bringing a session's window forward

Clicking a Codex session row asks Codex (macOS Apple Events automation) to raise
the window matching that session's project, in addition to the existing generic
app activation. The system shows a one-time permission prompt scoped to Codex
only, not system-wide Accessibility access. If the permission is denied, or
Codex has no matching window open, AgenticGlow silently falls back to today's
generic app activation. No window content, title, or other data is read back or
stored; the project name used to find the right window comes only from data
already collected (see Stored session fields above). Claude sessions are
unaffected: Claude's desktop app has no automation support to use here.

## Notifications

Optional notifications (agent needs permission, usage running low, or usage
exhausted) are composed and delivered locally through macOS Notification Center.
They contain only the provider name, project name, allowance percentage, window
label, and reset time when available, and involve no network request. Low and
exhausted alerts for one provider window reuse one notification identifier so an
exhausted alert replaces the earlier warning instead of adding another retained
notification.

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

## Desktop widget and shared App Group

The optional desktop widget runs in a separate, sandboxed process. The main app
writes one local `WidgetSnapshot.json` file to the private
`group.com.twodamax.agenticglow` App Group container so the widget can display
current status. The snapshot contains only the provider, session ID, project
name, phase, tool category, elapsed and update times, normalized allowance
values, and provider-installed flags already described above. It contains no
prompts, responses, commands, credentials, cookies, raw provider data, or file
contents. AgenticGlow atomically overwrites this single file rather than keeping
a widget history. The App Group is shared only by AgenticGlow and its own widget
extension and does not add any network request or cloud synchronization.
