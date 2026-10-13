# v0.8.2

## Fixed

- **Settings shows the iPhone sync status again.** With **Sync to the iPhone widget** on, Settings now says when it last published, or why it could not.

# v0.8.1

## Fixed

- **Settings opens again.** In v0.8.0, opening Settings closed AgenticGlow. The rest of the app was unaffected.

# v0.8.0

## New

- **Groundwork for an iPhone widget.** A new **Sync to the iPhone widget** setting publishes what the desktop widget shows to the private database of your own iCloud account, for an AgenticGlow iPhone widget. It is off by default, and nothing about it runs while it is off. The iPhone app is not yet available to install, so leave the setting off for now. There is no AgenticGlow server; see [docs/privacy.md](docs/privacy.md#iphone-widget-sync-optional-off-by-default) for exactly what is sent.

## Fixed

- **Codex usage reads again** after Codex moved its command-line tool, and keeps refreshing while a permission prompt is waiting.
- **The widget no longer passes old usage off as current.** A reading that has not refreshed for a while is labeled "Updated 2h ago", and the label appears on time.

## Changed

- Release builds embed a Developer ID provisioning profile for the iCloud entitlement, and a stricter check verifies the signed app's entitlements, profile and signatures before anything is notarized.

# v0.7.0

## New

- **Usage reset alerts.** When a provider's usage window has run out, AgenticGlow tells you when it is available again. It decides from two live readings in a row, not from the advertised reset time, so a network failure or an old cached reading can never fake a reset. Each reset is announced once, even across a relaunch.
- Alerts arrive as a macOS notification (on by default). You can also turn on an iMessage alert to a recipient you choose in Settings. The recipient is kept in your Keychain, and the message is sent through the Messages app on your Mac, so nothing passes through any server of ours.
- Choose which providers alert, and send a test alert from Settings.

## Changed

- The first iMessage alert asks for macOS Automation permission for Messages. AgenticGlow now carries the Apple Events entitlement this needs; macOS still asks before AgenticGlow can control any app.

# v0.6.1

## Fixed

- **No more false "Codex is waiting for permission" alerts.** When Codex's automatic reviewer handles an approval, nobody is waiting on you, so AgenticGlow no longer marks the session as needing permission or sends a notification. Requests you review yourself still alert as before. If AgenticGlow cannot tell who reviews a request, it assumes you do, so a real request is never hidden.
- To tell the two apart, the event helper reads the reviewer setting from the Codex session transcript on your Mac. Nothing from the transcript is stored or sent anywhere; see [docs/privacy.md](docs/privacy.md).

# v0.6.0

This is the initial curated public release of AgenticGlow, a local macOS menu bar app and widget for monitoring AI coding agent sessions.

## What's Included

- **Session Monitoring**: Real-time status for Codex, Claude Code, and Cursor Agent sessions
- **Menu Bar Interface**: See active sessions, permission requests, and usage status at a glance
- **Desktop Widget**: Optional small, medium, and large widgets showing session and allowance status
- **Usage Tracking**: Optional subscription allowance monitoring for all three providers
- **Privacy-First Design**: Runs entirely locally with no account system, backend, or telemetry
- **Notifications**: Alerts for permission requests and usage warnings

## Privacy

AgenticGlow runs entirely on your Mac. It has no account system, backend, analytics, telemetry, advertising, cloud sync, remote monitoring, or uploaded crash reports. Network requests are limited to optional GitHub release checks, explicit provider-specific subscription allowance access, and optional provider status checks. See [docs/privacy.md](docs/privacy.md) for the complete privacy contract.

## Installation

Download the signed and notarized DMG from the [Releases](https://github.com/FuturisticXx/AgenticGlow/releases) page and drag AgenticGlow to your Applications folder, or install via Homebrew:

```bash
brew install --cask FuturisticXx/agenticglow/agenticglow
```

## Requirements

- macOS 14.0 or later
- Apple Silicon (arm64) or Intel (x86_64)

## Documentation

- [README](README.md) - Complete installation and setup instructions
- [docs/privacy.md](docs/privacy.md) - Privacy contract and data handling
- [docs/integrations.md](docs/integrations.md) - Provider integration details
- [docs/widget.md](docs/widget.md) - Widget architecture and limitations

## License

MIT License - see [LICENSE](LICENSE) for details.