# Provider Allowance Feasibility

Reviewed July 3, 2026. This review uses current provider-owned documentation and
the locally installed provider clients. No live credential request was made.

## OpenAI Codex

Supported through the local `codex app-server` process. OpenAI documents the
`account/rateLimits/read` RPC and defines `usedPercent`, `windowDurationMins`,
and `resetsAt` for primary and secondary allowance windows:

- [OpenAI Codex app-server protocol](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)
- [OpenAI Codex authentication](https://developers.openai.com/codex/auth)

AgenticGlow starts the installed Codex app-server only after explicit Codex
opt-in. Codex itself reads its existing ChatGPT sign-in from its configured
credential store. AgenticGlow does not open `~/.codex/auth.json`, query the
Keychain, receive an authorization header, refresh credentials, or persist a
credential. API-key sessions do not represent subscription allowance and may
return unavailable data.

Local verification found Codex CLI 0.133.0. Its generated app-server schema
contains `account/rateLimits/read`, a primary window, an optional secondary
window, `usedPercent`, `windowDurationMins`, and `resetsAt`. The local Codex
credential file is user-only mode `0600`; only field names were inspected.

## Anthropic Claude

Anthropic documents the interactive `/usage` command and the session and weekly
limits shown in Claude settings. Anthropic does not document a programmatic
subscription-allowance endpoint for third-party apps:

- [Claude Code command reference](https://support.claude.com/en/articles/14553413-claude-code-cheatsheet)
- [Claude Pro usage limits](https://support.claude.com/en/articles/8325606-what-is-the-pro-plan)
- [Claude Code authentication and credential management](https://code.claude.com/docs/en/iam)

On macOS, Anthropic documents that Claude Code credentials are stored in the
encrypted macOS Keychain. AgenticGlow does not weaken that protection, request
the Claude Code Keychain secret, invoke or scrape the interactive `/usage`
screen, copy OAuth tokens, or call an undocumented endpoint. The Claude adapter
therefore reports a clear unsupported state and performs no network request.

## Revisit condition

The Claude adapter can be implemented when Anthropic publishes a supported
programmatic allowance interface and credential-use contract suitable for a
local third-party macOS app.
