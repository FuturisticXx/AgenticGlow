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

## Cursor

Optional, off by default, and behind explicit user-provided authentication.

### Prior conclusion (July 5, 2026), preserved

Unsupported. Cursor documents agent lifecycle hooks and a cloud Agents API, but
does not document a local programmatic subscription-allowance, plan-usage, or
spend interface for third-party Mac apps. AgenticGlow does not scrape
cursor.com account pages and does not store Cursor credentials. The allowance
UI omits Cursor rather than showing placeholder or guessed values.

### Reopened and decided (September 6, 2026)

The underlying fact has not changed. Re-verified on this date: Cursor's own API
index lists the Admin, Analytics, and AI Code Tracking APIs as Enterprise teams
only, and documents no endpoint through which an individual can read their own
remaining plan usage. Local state was also re-checked and holds nothing usable:
`~/.cursor` carries hooks, projects, and an AI-code-tracking database, and
Cursor's `state.vscdb` exposes only `cursorAuth/stripeSubscriptionStatus` and
slash-command counters. The `cursor-agent` CLI has no usage command.

- [Cursor APIs overview](https://cursor.com/docs/api)
- [Cursor usage and limits](https://cursor.com/help/models-and-usage/usage-limits)

What changed is the decision, not the evidence. AgenticGlow now offers Cursor
allowance as an opt-in integration authenticated by a session cookie the user
pastes into Usage Access, on the same terms already accepted for Claude.

### Trust boundary

- **No automatic credential extraction.** AgenticGlow never reads Cursor's
  cookie store, its `state.vscdb`, WorkOS session state, any browser cookie
  database, or any other application's credential storage. The only way a
  Cursor credential enters AgenticGlow is the user pasting it into the Usage
  Access sheet. This is a deliberate line: other tools do read Cursor.app's
  local token, and AgenticGlow does not.
- **Explicit consent.** Cursor usage is off unless the user turns it on, and
  turning it off deletes the stored credential.
- **Keychain only.** The cookie is stored under its own Keychain service,
  `com.twodamax.agenticglow.cursor-session.v1`, separate from Claude's. It is
  never written to UserDefaults, the widget snapshot, diagnostics, or logs, and
  is sent only to the Cursor endpoint below.
- **Private, undocumented endpoint.** `GET https://cursor.com/api/usage-summary`
  is the same call Cursor's own dashboard makes. It is read-only and mutates no
  account state. It is not a supported API, Cursor guarantees nothing about it,
  and it can change or stop working without notice.
- **Normalized data only.** AgenticGlow keeps two percentages, one reset date,
  and a fetch time. It does not store the raw response, account email, account
  ID, or any spend figure.

### Pools

Cursor's current plans meter two separate allowances, and AgenticGlow shows
them separately because they have separate denominators:

| Displayed as | Source field | Meaning |
| --- | --- | --- |
| Cursor Models | `individualUsage.plan.autoPercentUsed` | Cursor's own models (Composer, Auto, Cursor Grok) |
| Other Models | `individualUsage.plan.apiPercentUsed` | Third-party named models |

Both reset at `billingCycleEnd`. Values are already in percentage units,
including fractional values below 1.0.

### Mapping verified against a live account (September 6, 2026)

This table is not an inference from field names. It was checked against a
real Pro account by enabling Usage Access and comparing AgenticGlow's
normalized cache with what cursor.com's own dashboard displayed at the same
moment. The two pools carried clearly different values, so a swap would have
been visible:

| | Cursor dashboard (used) | AgenticGlow stored (used) | AgenticGlow displayed (left) |
| --- | --- | --- | --- |
| Cursor Models | 96% | 96.013% | 4% |
| Other Models | 82% | 82.444% | 18% |

`billingCycleEnd` resolved to September 16, matching the dashboard's billing
date. No combined Cursor figure was written: the stored record carried the two
pools and no current or weekly percentage at all.

The percentages are stored exactly as Cursor reports them, with no scaling
anywhere in the path, which is what makes a fractional reading such as `0.36`
mean 0.36% rather than 36%. The live check landed at 96.013 and 82.444, values
that would not have matched the dashboard had any scaling been applied; the
sub-1% case itself is covered by unit tests rather than by this reading.

None of this makes the endpoint supported. It remains private and
undocumented, and Cursor can change it without notice.

No combined Cursor figure is produced. `totalPercentUsed` is deliberately
ignored, and the two lane percentages are never summed or averaged: with two
denominators there is no honest single number, and an average would read as a
health reading that is true of neither pool.

### Revisit condition

Replace this connection with a supported interface if Cursor publishes a
documented individual usage API. Remove it if Cursor's terms come to prohibit
reading this endpoint with the user's own session.

## Revisit condition

Replace the private Claude connection if Anthropic publishes a supported
programmatic allowance interface and credential-use contract for local apps.

Cursor allowance ships as described above: opt-in, user-supplied credential,
private endpoint, and disclosed as unofficial in the Usage Access sheet.
