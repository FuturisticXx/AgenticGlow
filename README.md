# AgenticGlow

AgenticGlow is a local macOS menu bar app that shows the status of your AI coding agent sessions.

## Requirements

- macOS 14.0 or later
- Apple Silicon (arm64) or Intel (x86_64)

## Supported Providers

- **Codex**: CLI sessions
- **Claude**: Desktop app sessions

## Installation

No public release has been published yet. The commands below apply after the
first signed and notarized release is available.

### DMG

Download the latest DMG from the [Releases](https://github.com/FuturisticXx/AgenticGlow/releases) page and drag AgenticGlow to your Applications folder.

### Homebrew

```bash
brew install --cask agenticglow
```

## Setup

1. Launch AgenticGlow from Applications
2. In the setup window, click "Install" for each provider you use
3. For Codex, open Codex, run `/hooks`, review the AgenticGlow entries, and choose "Trust"
4. Click "Done" when complete

## Privacy

AgenticGlow runs entirely on your Mac. It has no account system, backend, analytics, telemetry, advertising, cloud sync, remote monitoring, or uploaded crash reports. It stores only session metadata (provider, phase, project name, timestamps) and never stores prompts, responses, commands, or tool arguments. Network requests are limited to optional GitHub release checks and explicit, provider-specific subscription allowance access. Usage access is off by default. Codex allowance uses the installed local Codex app-server, which manages its own sign-in. Claude allowance remains unavailable until Anthropic publishes a supported programmatic interface.

See [docs/privacy.md](docs/privacy.md) for the complete privacy contract.

## Building

```bash
brew install xcodegen
xcodegen generate
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS' \
  -skip-testing:AgenticGlowUITests \
  CODE_SIGNING_ALLOWED=NO
```

## Attribution

AgenticGlow is an independent implementation inspired by Mick Cesanek's MIT-licensed Claude Status Bar project. AgenticGlow does not reuse that project's source code or branding.

## License

MIT License - see [LICENSE](LICENSE) for details.
