# AgenticGlow Design Specification

Date: June 25, 2026

Status: Approved product design, pending user review of this written specification

## Summary

AgenticGlow is a free, open-source macOS menu bar utility that shows the live status of local Codex and Claude coding sessions.

The app provides one glanceable indicator for all supported sessions. Its menu lists each active session, the source application, current state, project, and elapsed turn time. Users can select a session to bring its source application to the foreground.

AgenticGlow is local-only. It does not require an account, operate a backend, collect analytics, upload prompts, or store model responses.

## Product Goal

Help developers answer three questions without repeatedly switching applications:

1. Is an agent still working?
2. Does an agent need permission or attention?
3. Which project and application should I return to?

## Target Users

- Developers who use Codex and Claude on the same Mac.
- Developers who run multiple agent sessions simultaneously.
- Users who want lightweight status visibility without adopting a monitoring platform.

## Supported Platforms

- macOS 14 or newer.
- Apple Silicon and Intel Macs.
- Codex CLI.
- Codex Desktop.
- Claude Code CLI.
- Claude Desktop's Code surface.

Support depends on the source application emitting its documented local lifecycle hooks. AgenticGlow's diagnostics must report when an installed version does not expose the required events.

## Working Product Name

The working product name is **AgenticGlow**.

This name has known conflicts with existing software brands, including an AI software company and an existing macOS utility. Public release under this name requires a separate clearance pass covering:

- United States trademark records and relevant international markets.
- App marketplaces.
- GitHub organization and repository names.
- Homebrew Cask token availability.
- Practical domain and social handle availability.

Implementation may proceed under the AgenticGlow working title. Public branding, release packaging, and external publication must stop if the clearance pass identifies unacceptable confusion or legal risk.

## Product Principles

- One glance should communicate whether attention is required.
- Monitoring must not alter agent behavior.
- Hooks must collect only the metadata required for status display.
- Installation and removal must preserve unrelated user configuration.
- Each provider must continue working if the other provider fails.
- Native macOS behavior takes priority over visual novelty.
- No feature should require an account, subscription, server, or paid API.

## V1 Scope

### Included

- One combined menu bar indicator.
- Multiple simultaneous Codex and Claude sessions.
- Thinking, tool use, permission, completion, idle, and disconnected states.
- Optional elapsed turn timer.
- A dropdown containing every active session.
- Best-effort activation of the source application.
- First-launch integration setup.
- Integration diagnostics, repair, and clean removal.
- Launch at login.
- Manual update checks and an optional automatic GitHub release check.
- Signed and notarized DMG distribution.
- Homebrew Cask distribution.
- Universal macOS build for arm64 and x86_64.

### Excluded

- Approving or denying permissions from AgenticGlow.
- Displaying prompts, responses, tool inputs, command text, or file contents.
- Remote monitoring or synchronization.
- User accounts.
- Analytics, telemetry, or uploaded crash reports.
- Windows and Linux.
- Cursor and additional coding agents.
- Mac App Store distribution.
- Exact deep-linking into every terminal tab or agent thread.

## Architecture

AgenticGlow uses a native SwiftUI and AppKit menu bar application, a small native event helper, provider-specific hook definitions, and local per-session state files.

### Components

#### 1. AgenticGlow macOS application

Responsibilities:

- Watch the local session-state directory.
- Decode and validate normalized events.
- Maintain the in-memory session model.
- Resolve the combined menu bar state.
- Render the status item and session menu.
- Activate the source application when a user selects a session.
- Run setup, diagnostics, repair, update checks, and preferences.
- Clean expired session files.

The application uses SwiftUI for setup and settings surfaces and AppKit where direct `NSStatusItem`, menu, application activation, or process APIs provide better control.

#### 2. AgenticGlow event helper

AgenticGlow ships a small universal command-line executable at a stable user-level path under:

`~/Library/Application Support/AgenticGlow/bin/`

Hook commands invoke this helper with the provider and event type. The helper:

- Reads the provider's JSON hook payload from standard input.
- Extracts only approved metadata.
- Maps provider-specific fields into the normalized event schema.
- Identifies the likely source application and parent agent process.
- Writes one atomic state file per session.
- Returns quickly and silently.

The helper does not depend on Node.js, Python, a package manager, or a background daemon.

#### 3. Claude integration

The setup wizard merges AgenticGlow handlers into Claude's supported hook configuration for:

- `SessionStart`
- `SessionEnd`
- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `Notification`
- `PermissionRequest`
- `Stop`

The integration must preserve existing hooks and remove only entries carrying AgenticGlow's unique marker.

#### 4. Codex integration

The setup wizard merges AgenticGlow handlers into the user-level Codex hook configuration for:

- `SessionStart`
- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `PermissionRequest`
- `Stop`

Codex requires users to review and trust new or changed non-managed hooks. AgenticGlow must explain this requirement and provide direct instructions to open Codex's `/hooks` interface. AgenticGlow must not bypass hook trust.

Codex does not currently provide the same session-end event used by Claude. AgenticGlow therefore uses source-process liveness and conservative expiration rules for Codex cleanup.

#### 5. Local state store

Normalized state files live under:

`~/Library/Application Support/AgenticGlow/Sessions/`

Each provider and session receives a separate file. Writes use a temporary file followed by an atomic rename so the app never reads partial JSON.

Directory permissions must be user-only. Session files must not be shared across accounts.

## Normalized Event Schema

The versioned schema contains only the information needed for status display and lifecycle management:

```json
{
  "schemaVersion": 1,
  "provider": "codex",
  "surface": "desktop",
  "sessionID": "provider-session-id",
  "turnID": "provider-turn-id",
  "phase": "usingTool",
  "label": "Editing",
  "toolCategory": "edit",
  "projectName": "ExampleProject",
  "workingDirectory": "/local/path/ExampleProject",
  "sourceBundleID": "com.openai.codex",
  "sourceProcessID": 1234,
  "sourceProcessStartedAt": 1782400000,
  "turnStartedAt": 1782400010,
  "updatedAt": 1782400020
}
```

Allowed phases:

- `idle`
- `thinking`
- `usingTool`
- `permission`
- `completed`
- `disconnected`

AgenticGlow stores no prompt text, assistant message, tool arguments, shell command, tool response, transcript contents, or file contents.

`workingDirectory` remains local and exists only to identify the project and support source-application activation. The menu displays only `projectName` by default.

## Provider Event Mapping

| Provider event | AgenticGlow phase | Timer behavior |
| --- | --- | --- |
| Session start | idle | No timer |
| User prompt submitted | thinking | Start or replace turn timer |
| Before tool use | usingTool | Preserve turn timer |
| After tool use | thinking | Preserve turn timer |
| Permission request | permission | Preserve turn timer internally, hide it in the status title |
| Stop | completed | Stop timer |
| Session end | remove or idle | Stop timer |

Known tool names map to short categories such as Reading, Editing, Searching, Browsing, Running command, and Delegating. Unknown tools use the label `Using tool`.

## Multi-Session State Resolution

The menu bar shows one combined state using this priority:

1. Permission required.
2. Using a tool.
3. Thinking.
4. Recently completed.
5. Idle.

When multiple sessions share the highest priority, the indicator may add a compact count. The menu always lists each session separately.

Completed status remains visible briefly before becoming idle. The default completion display duration is eight seconds.

## Lifecycle and Stale-State Recovery

Each event records the likely long-lived Codex or Claude process identifier and process start time. The app checks both values before treating a process as alive, preventing PID reuse from preserving an invalid session.

Recovery rules:

- A new event always replaces the prior state for the same session.
- A completed state becomes idle after the completion display duration.
- A session becomes disconnected when its recorded source process no longer exists.
- Disconnected sessions remain visible briefly so the user understands what happened.
- Sessions without reliable process metadata use a conservative four-hour inactivity fallback.
- Session files older than 24 hours are removed.
- Claude `SessionEnd` removes its session promptly.
- Denied permissions, interrupted turns, crashes, and force quits must not leave permanent working animations.

The app must never inspect transcript contents to determine state.

## Menu Bar Experience

### Status item

- Use a neutral AgenticGlow symbol rather than OpenAI or Anthropic branding.
- Animate when any session is thinking or using a tool.
- Use a yellow attention treatment when permission is required.
- Offer an optional elapsed timer beside the icon.
- Respect Reduce Motion by replacing continuous animation with a static state change.
- Remain visible while AgenticGlow is running, including when no session is active.

### Session menu

The menu contains:

1. A compact summary such as `3 active sessions`.
2. Sessions grouped under Codex and Claude.
3. One row per session showing:
   - Project name.
   - Current status.
   - Elapsed turn time when applicable.
   - Source surface, such as CLI or Desktop.
4. Integration health when a provider is disconnected or misconfigured.
5. Preferences, integration setup, update check, and quit actions.

Permission rows appear first. Remaining rows sort by most recent activity.

### Source activation

Selecting a session activates its source application.

- Desktop surfaces activate Codex or Claude Desktop.
- CLI surfaces activate the detected terminal application.
- Exact terminal tab, window, or agent-thread focusing is attempted only when a stable supported mechanism exists.
- If exact focusing is unavailable, AgenticGlow brings the correct application to the foreground and clearly avoids claiming deeper navigation.

## Setup and Integration Management

### First-launch wizard

1. Explain what AgenticGlow monitors and what it does not collect.
2. Detect installed Codex and Claude versions.
3. Show each integration independently.
4. Install selected integrations using safe configuration merges.
5. Create a timestamped backup before the first modification.
6. Run a local synthetic event through each installed helper.
7. Confirm that AgenticGlow receives and displays the test session.
8. Explain Codex hook trust and how to approve the installed hooks.
9. Offer launch at login.
10. Offer manual update checks or opt-in automatic GitHub release checks.

### Diagnostics

For each provider, diagnostics report:

- Application or CLI detected.
- Supported version detected.
- Hook definition installed.
- Hook command points to the current helper.
- Hook trust may still be required.
- Test event received.
- Last real event received.

### Repair

Repair removes stale AgenticGlow entries, installs the current entries, preserves unrelated configuration, and repeats the synthetic event test.

### Removal

Removal deletes only AgenticGlow-marked hook entries and AgenticGlow-owned local state. It does not restore an entire backup over newer user settings.

## Privacy and Security

- No account.
- No backend.
- No analytics.
- No telemetry.
- No uploaded crash reports.
- No prompt, response, command, or tool-argument storage.
- No remote monitoring.
- No network access except user-initiated update checks or an explicitly enabled automatic GitHub release check.
- Automatic update checks are opt-in.
- Hook commands use absolute paths.
- Configuration merging validates JSON before replacement.
- Writes are atomic and constrained to AgenticGlow-owned paths.
- The helper rejects unsupported schema versions and malformed provider payloads.
- Files use user-only permissions.
- Symlinks and unexpected file ownership must not be followed during configuration or state writes.

A public privacy document must list every stored field and every possible network request.

## Error Handling

- Malformed events are ignored and recorded only in an optional local diagnostic log.
- Diagnostic logs are off by default and never include raw hook payloads.
- Failure of one provider does not disable the other.
- Missing configuration produces a repair action, not repeated alerts.
- Unsupported provider versions produce a clear compatibility message.
- The menu bar must settle to a safe idle or disconnected state after crashes and force quits.
- Update-check failures remain silent except inside the update interface.

## Accessibility

- Full keyboard access for setup, preferences, and menus.
- VoiceOver labels for provider, project, status, timer, and actions.
- Do not communicate status by color alone.
- Sufficient contrast in Light Mode and Dark Mode.
- Native focus indicators.
- macOS-standard click targets.
- Reduced Motion support.
- Timer updates must not create continuous VoiceOver announcements.

## Testing Strategy

### Unit tests

- Provider payload normalization.
- Event schema validation.
- State priority.
- Timer calculation.
- Tool-category mapping.
- Process identity and stale cleanup.
- JSON configuration merge and removal.
- Backup behavior.
- Sorting and grouping.

### Integration tests

- Fixtures for every supported Claude and Codex event.
- Multiple simultaneous sessions.
- Interrupted and denied permission flows.
- Provider crashes and force quits.
- Existing unrelated hooks.
- Invalid configuration files.
- Synthetic setup and repair tests.

### UI tests

- First launch.
- No integrations.
- One provider installed.
- Both providers installed.
- Permission required.
- Multiple active sessions.
- Completed session.
- Disconnected integration.
- Repair and removal.

### Release verification

- Build and test on macOS 14 or newer.
- Verify arm64 and x86_64 slices.
- Verify Developer ID signature.
- Verify notarization and stapling.
- Install, upgrade, and remove through the DMG.
- Install, upgrade, and remove through Homebrew Cask.
- Test VoiceOver, keyboard access, contrast, and Reduce Motion.

## Distribution

- Source hosted in a public GitHub repository after explicit publication approval.
- MIT license for AgenticGlow's original code.
- README credits the original MIT-licensed Claude Status Bar project as product inspiration while clearly stating that AgenticGlow is an independent implementation.
- GitHub Releases host the signed and notarized universal DMG.
- A Homebrew Cask installs the same signed application.
- DMG users receive a release-page link when an update is available.
- Homebrew users update through Homebrew.
- AgenticGlow does not silently download or install updates.

## Proposed Repository Structure

```text
AgenticGlow/
├── AgenticGlow.xcodeproj
├── App/
│   ├── Application/
│   ├── MenuBar/
│   ├── Sessions/
│   ├── Integrations/
│   ├── Setup/
│   ├── Preferences/
│   └── Resources/
├── Helper/
│   ├── EventSchema/
│   ├── ClaudeAdapter/
│   ├── CodexAdapter/
│   └── StateWriter/
├── Tests/
│   ├── AppTests/
│   ├── HelperTests/
│   ├── IntegrationFixtures/
│   └── UITests/
├── Scripts/
│   ├── build-release.sh
│   ├── verify-release.sh
│   └── generate-cask.sh
├── docs/
│   ├── architecture/
│   ├── privacy/
│   └── superpowers/specs/
├── LICENSE
└── README.md
```

The final implementation may use an Xcode workspace or Swift packages if that improves testability, but it must preserve the boundaries between the UI, normalized session model, provider adapters, configuration management, and state writer.

## Acceptance Criteria

AgenticGlow v1 is complete when:

1. Codex CLI, Codex Desktop, Claude Code CLI, and Claude Desktop Code events appear in one menu bar app on supported versions.
2. Two or more simultaneous sessions remain independent and display correctly.
3. Permission state outranks all other states.
4. Selecting a session activates the correct source application.
5. Setup safely merges integrations and proves them with a synthetic test event.
6. Repair and removal touch only AgenticGlow-owned entries and files.
7. Crashes, interruptions, denied permissions, and force quits do not leave permanent active indicators.
8. No prohibited content is written to AgenticGlow's state or logs.
9. The app passes unit, integration, UI, accessibility, universal-build, signing, notarization, DMG, and Homebrew verification.
10. Public release is blocked until the AgenticGlow name and distribution identifiers receive explicit clearance.

## Reference Sources

- Original product inspiration: <https://github.com/m1ckc3s/claude-status-bar>
- Current Codex hook documentation: <https://developers.openai.com/codex/hooks>
- Apple menu bar guidance: <https://developer.apple.com/design/Human-Interface-Guidelines/the-menu-bar>
- Existing AgenticGlow AI company: <https://www.agenticglow.ai/>
- Existing AgenticGlow Disk macOS listing: <https://apps.apple.com/us/app/agenticglow-disk/id6758895498>

