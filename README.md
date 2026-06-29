# Klarity

Klarity is a local macOS menu bar app that shows the status of your AI coding agent sessions.

## Requirements

- macOS 14.0 or later
- Apple Silicon (arm64) or Intel (x86_64)

## Supported Providers

- **Codex**: CLI sessions
- **Claude**: Desktop app sessions

## Installation

### DMG

Download the latest DMG from the [Releases](https://github.com/jwright0180/Klarity/releases) page and drag Klarity to your Applications folder.

### Homebrew

```bash
brew install --cask klarity
```

## Setup

1. Launch Klarity from Applications
2. In the setup window, click "Install" for each provider you use
3. For Codex, open Codex, run `/hooks`, review the Klarity entries, and choose "Trust"
4. Click "Done" when complete

## Privacy

Klarity runs entirely on your Mac. It has no account system, backend, analytics, telemetry, advertising, cloud sync, remote monitoring, or uploaded crash reports. It stores only session metadata (provider, phase, project name, timestamps) and never stores prompts, responses, commands, or tool arguments. Network requests are limited to optional GitHub release checks when you manually check for updates or enable automatic update checks.

See [docs/privacy.md](docs/privacy.md) for the complete privacy contract.

## Building

```bash
brew install xcodegen
xcodegen generate
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -skip-testing:KlarityUITests \
  CODE_SIGNING_ALLOWED=NO
```

## Attribution

Klarity is an independent implementation inspired by Mick Cesanek's MIT-licensed Claude Status Bar project. Klarity does not reuse that project's source code or branding.

## License

MIT License - see [LICENSE](LICENSE) for details.
