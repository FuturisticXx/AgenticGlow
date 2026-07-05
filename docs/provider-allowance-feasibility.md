# Provider Allowance Feasibility

Reviewed July 5, 2026. This review uses provider-owned documentation, locally
installed provider clients, and credential-safe live validation on this Mac.

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

AgenticGlow offers an explicitly unofficial connection for users who choose it.
The user supplies the full Cookie request header from `claude.ai` Settings >
Usage. AgenticGlow stores it as a generic password in macOS Keychain, extracts
the `lastActiveOrg` cookie field, and requests:

`https://claude.ai/api/organizations/{organization}/usage`

The response currently exposes `five_hour` and `seven_day` windows with
`utilization` and `resets_at`. A live Foundation `URLSession` check returned
HTTP 200 on July 5, 2026 and matched the separately installed ClaudeUsageBar
display. AgenticGlow stores only normalized percentages, reset times, and fetch
time. It does not store the raw response or cookie outside Keychain.

This is a private web endpoint, not a supported Anthropic API. It can change or
stop working without notice. HTTP 401 or 403 is treated as an expired cookie and
the UI instructs the user to update Usage Access.

## Revisit condition

Replace the private Claude connection if Anthropic publishes a supported
programmatic allowance interface and credential-use contract for local apps.
