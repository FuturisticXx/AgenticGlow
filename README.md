# AgenticGlow

AgenticGlow is a local macOS menu bar app that shows the status of your AI coding agent sessions. It notifies you when an agent needs your permission, warns once when a usage window runs low, alerts once when the window is exhausted, hints low allowance on the menu bar icon, and can optionally show provider service incidents.

## Requirements

- macOS 14.0 or later
- Apple Silicon (arm64) or Intel (x86_64)

## Supported Providers

- **Codex**: Codex app and CLI sessions
- **Claude**: Claude Code sessions

## Installation

The latest signed and notarized public release is
[v0.5.3](https://github.com/FuturisticXx/AgenticGlow/releases/tag/v0.5.3).

### DMG

Download the latest DMG from the [Releases](https://github.com/FuturisticXx/AgenticGlow/releases) page and drag AgenticGlow to your Applications folder.

### Homebrew

```bash
brew install --cask FuturisticXx/agenticglow/agenticglow
```

## Setup

1. Launch AgenticGlow from Applications
2. In the setup window, click "Install" for each provider you use
3. For Codex, open Codex, run `/hooks`, review the AgenticGlow entries, and choose "Trust"
4. Click "Done" when complete

### Optional subscription allowance

Open the AgenticGlow menu, choose **Usage Access…**, and enable providers
individually. Codex uses the installed local Codex app-server and its existing
sign-in. Claude uses an unofficial private `claude.ai` connection because
Anthropic does not publish a supported usage API:

1. Open `claude.ai` and go to **Settings > Usage**.
2. Open the browser developer tools and refresh the page.
3. Select the `usage` network request.
4. Copy the complete `Cookie` request header value.
5. Paste it into AgenticGlow's Claude session cookie field.

AgenticGlow stores the Claude cookie only in macOS Keychain. Disabling Claude
usage deletes it. If Claude reports that the cookie expired, repeat these steps.

### Jumping to a Codex session

Clicking a Codex session brings its window forward, including across
displays. The first time you do this, macOS asks for permission to let
AgenticGlow control Codex (ChatGPT) automation. This is a one-time, Codex-only
prompt, not the broader Accessibility permission. If you decline, or later
revoke it in **System Settings > Privacy & Security > Automation**, clicking a
Codex session still brings Codex forward generally, just without jumping to
that exact window. Claude sessions are unaffected either way.

## Privacy

AgenticGlow runs entirely on your Mac. It has no account system, backend, analytics, telemetry, advertising, cloud sync, remote monitoring, or uploaded crash reports. It stores only session metadata (provider, phase, project name, timestamps) and never stores prompts, responses, commands, or tool arguments. Network requests are limited to optional GitHub release checks, explicit provider-specific subscription allowance access, and optional provider status checks. Usage access is off by default. Codex allowance uses the installed local Codex app-server, which manages its own sign-in. Optional Claude allowance uses an explicitly disclosed private `claude.ai` endpoint and a user-supplied session cookie stored only in macOS Keychain. Optional provider incident display (off by default) fetches only the public, unauthenticated Anthropic and OpenAI status pages.

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
