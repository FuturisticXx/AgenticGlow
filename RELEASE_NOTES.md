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