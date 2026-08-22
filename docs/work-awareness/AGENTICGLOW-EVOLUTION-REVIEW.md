# AgenticGlow Evolution Review

Date: 2026-08-21
Scope: investigation and product strategy only. No code was changed.
Latest public GitHub release: v0.5.11 (2026-07-25). Running local install: **0.5.13-dev** at `/Applications/AgenticGlow.app`, with the widget extension also running. Current tree includes Cursor as a first-class provider (logged 2026-08-17).

Evidence labels used throughout:

- **Observed:** verified in AgenticGlow source or live local data on this Mac.
- **Documented:** first-party AgenticGlow or provider documentation.
- **Inferred:** reasoned from evidence, not directly proven.
- **Proposed:** a design recommendation.

---

## 1. Executive Summary

AgenticGlow is already the best version of what it set out to be: a calm, private, local macOS glancer for AI coding sessions. That identity is working. The incomplete feeling is not "it needs more features." It is that the product still thinks in **isolated agent sessions**, while daily work now happens as **connected development work across harnesses and models**.

Tonight's live state on this Mac makes the gap concrete. **Observed:** three Cursor sessions were simultaneously active in `/Volumes/Liquid/2DaMax Development/AgenticGlow`, using `grok-4.6`, `claude-sonnet-5-thinking-high`, and `composer-2.5-fast`. Claude's weekly window sat at **1% left**. Codex weekly sat at **56% left**. Cursor usage was absent, as designed. The popover can show those facts as separate rows and bars. It cannot say the sentence a developer actually needs:

> Three models are in AgenticGlow. Claude weekly is effectively gone. Codex still has room. Cursor Grok is a different usage pool than Claude Sonnet.

That is the missing layer: **work identity, honest capability differences, and decision support**, without becoming an IDE, a Dynamic Island control tower, or an agent orchestrator.

**Verdict:** EVOLVE WITH TARGETED STRUCTURAL CHANGES.

---

## 2. What AgenticGlow Is Today

### Product thesis (original)

**Documented** in `docs/superpowers/specs/2026-06-25-agenticglow-design.md` and `PRODUCT.md`:

Help a Mac developer answer three questions without switching apps:

1. Is an agent still working?
2. Does an agent need permission or attention?
3. Which project and application should I return to?

Brand: calm, native, quietly expressive, trustworthy, precise. Local-only. No account, backend, analytics, prompt storage, or remote monitoring.

### Primary jobs

1. Ambient awareness of local AI coding activity. **Observed.**
2. Interrupt when an agent needs permission. **Observed.**
3. Show Codex and Claude subscription allowance at a glance. **Observed.**

### Secondary jobs

- First-launch hook installation, repair, and clean removal. **Observed.**
- Optional provider incident strip. **Observed.**
- Desktop widget as a passive glance. **Documented** in `docs/widget.md`.
- Codex window raise on click. **Observed** in `SourceApplicationActivator`.
- Weekly-reset celebration on the menu bar icon. **Observed.**
- Global shortcut to show the popover. **Observed.**

### Major UI surfaces

| Surface | Role today | Depth |
| --- | --- | --- |
| Menu bar icon | Combined status: working / needs you / idle / failed / low allowance | Immediate |
| Popover (360pt) | Session list + allowance + gear menu | Fast |
| Setup window | Install / Repair / Remove per provider | Occasional |
| Settings | Timer, icon style, glass, shortcut, notifications, incidents, updates, login item | Occasional |
| Desktop widget | Small / medium / large snapshot | Passive |
| Notifications | Permission entered; usage low; usage exhausted | Event |

There is **no main application window** for history, analysis, or work overview. **Observed** in `AppDelegate.swift`: accessory app, popover, Setup, Settings, UI-test fixture window only.

### How this Mac actually uses it

**Observed** from the running 0.5.13-dev process, UserDefaults, hook configs, and live session files on 2026-08-21:

- All three hook integrations are installed and enabled (Codex 6 events, Claude 8, Cursor 7).
- Cursor is the primary harness today: four of six session files, three concurrent AgenticGlow models.
- Claude is secondary (Caliber Wallet worktree plus a duplicated Grok-attributed row).
- Codex hooks and allowance are on, but there were **no live Codex session files**.
- Preferences in daily use: elapsed timer on, **monochrome** menu bar icon, global shortcut ⇧⌘A, permission and quota notifications on, provider incidents on, usage access on for Codex and Claude, automatic update checks off.
- The desktop widget process was running alongside the app.

This is already past the June 2026 thesis of a Codex-and-Claude status menu. The daily loop is: leave AgenticGlow running, glance the bar, open the popover when usage or overlap might matter, jump back into Cursor or Claude.

### Data sources

| Source | What it contributes | Privacy posture |
| --- | --- | --- |
| Provider hooks via `agenticglow-event` | Session identity, phase, project basename, cwd, tool category, optional model | Metadata only. **Documented** in `docs/privacy.md` |
| Codex `thread/list` fallback | Presence when hooks cannot launch | No transcripts. **Documented** |
| Codex `account/rateLimits/read` | 5h / weekly windows | Opt-in, local app-server. **Documented** |
| Unofficial `claude.ai` usage endpoint | 5h / weekly windows | Opt-in cookie in Keychain. **Documented** |
| Statuspage JSON | Incident description | Opt-in, public GET. **Documented** |
| Widget App Group snapshot | Derived view of the above | Local, no history. **Documented** |

Cursor has session hooks and **no** documented local usage API. **Documented** in `docs/integrations.md` and `docs/provider-allowance-feasibility.md`.

### Background processes

- 2-second `AppModel.refresh()` poll over session files. **Observed.**
- Codex discovery every 15 seconds. **Documented.**
- Allowance refresh: 4s after a turn ends, 60s while working, 5 min idle, 15s max-age when the popover is open. **Observed** in `AllowanceRefreshPolicy`.
- Widget timeline reload only when the snapshot is meaningfully different. **Documented.**
- Helper binary auto-refresh on launch. **Documented** in `gotdone.md`.

### Session monitoring

Normalized phases: `idle`, `thinking`, `usingTool`, `permission`, `completed`, `disconnected`, `failed`. **Observed.**

Priority sort: permission > usingTool > thinking > failed > completed > disconnected > idle. **Observed** in `SessionResolver`.

Staleness: thinking/usingTool rolls to idle after 30 minutes without updates, because Codex's `app-server` is a shared process. Permission is exempt. **Documented** in `docs/integrations.md` and `tasks/lessons.md`.

Files are overwritten in place. Retention is 24 hours. Completed rows display for 8 seconds, disconnected for 15. **Observed.**

### Allowance / usage

Codex and Claude only. Cursor omitted rather than faked. **Documented.** Latest snapshot only: percent used/left, reset time, fetch time. No history, no burn rate, no "safest provider" comparison. **Observed** in `ProviderAllowance` and `FileAllowanceCache`.

Low-window threshold is 10%. Exhausted is 0%. **Observed** in `AllowanceWarning` and `QuotaAlertTracker`.

### Notifications

- Agent newly entered `.permission`.
- Usage running low.
- Usage exhausted (replaces the low alert for that window).

Not notified: failed, stalled, completed, same-repo collision, model switch, weekly reset (reset is celebrated on the icon, not notified). **Observed** in `NotificationPolicy` and `AgentNotificationService`.

### Agent / provider integrations

Closed enum: `AgentProvider { codex, claude, cursor }`. **Observed.**

Shared path: hook JSON -> helper -> `NormalizedEvent` -> session file -> `SessionResolver` -> UI.

Provider-specific special cases already exist:

- Cursor payload adapter (`conversation_id`, `workspace_roots`, `stop.status`).
- Cursor hook file shape (`cursorEntry`, camelCase names, no `failClosed`).
- Codex app-server discovery and window script.
- Claude cookie allowance adapter.
- Cursor cannot detect permission prompts. **Documented.**

### Model awareness

`NormalizedEvent.model` exists. Cursor sends `model` / `model_id`. Compact rows do not show it. Expanded detail does. **Observed** in `SessionDetailPresentation` and live session files.

There is no model catalog, no harness-versus-model split, and no usage-pool mapping (Cursor Models vs Other Models). **Observed.**

### Current user actions

| Action | Where | Reliability |
| --- | --- | --- |
| Open popover | Menu bar, global shortcut, widget `agenticglow://open` | High |
| Activate source app | Click session row | Codex: window raise. Claude/Cursor: generic activate. **Observed.** |
| Expand session detail | Chevron | High |
| Hide a non-running row | Context menu Remove | Client-side hide until a newer event. **Observed.** |
| Refresh usage | Gear menu | Codex/Claude only |
| Usage Access, Integrations, Settings, Quit | Gear menu | High |
| Click notification | Activates bundle ID, not a specific session | Partial |
| Widget row deep link | Medium/large | Provider + session ID |

There is no: resume, answer, approve, terminate, copy context, prepare handoff, switch provider, open repo, or reveal terminal.

### Architectural limitations

1. `AgentProvider` is a closed three-case enum. New harnesses require source edits across UI, colors, setup, widget, notifications, and tests.
2. `workingDirectory` is stored on disk and dropped before `SessionSnapshot`. The UI cannot group or conflict-detect by repo. **Observed.**
3. Session files are latest-state only. "What happened while I was away" cannot be reconstructed. **Observed.**
4. Capability differences are implicit. Cursor looks like a third Codex/Claude peer, then silently lacks permission and usage. **Observed.**
5. The popover summary can report only one clause at a time. **Observed** in `SessionListView.summary`.
6. No branch, git identity, task text, or context-pressure field reaches the snapshot, even where a provider already exposes one (Cursor `preCompact.context_usage_percent`). **Documented** in Cursor hooks; **Observed** as not installed.

---

## 3. What It Does Exceptionally Well

Protect these. They are the product.

1. **Glanceable honesty.** One menu bar icon, one short popover, no fake precision. Uncertainty is shown as Unavailable, Cached, or omitted, not invented. **Documented** in `PRODUCT.md`.
2. **Privacy as a feature.** Metadata only. No prompts, transcripts, tool I/O, or accounts. Cursor payload stripping is explicit. **Documented.**
3. **Fail-open integrations.** Hooks never block the agent. Cursor entries never set `failClosed`. Removal is marker-scoped. **Documented.**
4. **Attention without alarm.** Permission is amber, not red. Failed is distinct from disconnect. The widget reports status rather than prompting. Motion is reserved. **Observed** and **Documented.**
5. **Native macOS craft.** Liquid Glass, Reduce Motion, VoiceOver elapsed time, Tinted widget geometry, Team-ID App Groups, inside-out signing. This is unusually high craft for a menu bar utility. **Observed.**
6. **Provider-colored working state.** You can tell who is working from the icon without opening anything. **Observed.**
7. **Allowance as a second, quieter question.** Sessions first, usage below. Opt-in. Cursor omitted rather than scraped. **Documented.**

These are why it is already a daily tool. Do not trade them for a dashboard.

---

## 4. Current Product Friction

Distinguish the kind of gap.

### Missing functionality

- Work / repo grouping.
- History beyond the latest event.
- Usage decision support (rate, reset meaning, safest continuation).
- Stalled-session attention distinct from idle.
- Cursor permission and usage.
- Context-window pressure.
- Any recommendation layer.
- A deeper window for history and configuration (Settings exists; understanding does not).

### Hidden functionality

Data already collected but weakly or never shown:

| Field | Collected | Shown |
| --- | --- | --- |
| `workingDirectory` | Yes, on `NormalizedEvent` | No. Dropped at `SessionSnapshot`. **Observed.** |
| `model` | Yes, when the hook sends it | Expanded detail only. **Observed.** |
| `toolCategory` | Yes | Row icon while using a tool. Compact text still says "Reading · Desktop". **Observed.** |
| `updatedAt` | Yes | Expanded "Last updated" only. **Observed.** |
| `turnStartedAt` | Yes | Expanded "Started" only. **Observed.** |
| Same cwd across sessions | Yes, on disk | Never compared. **Observed.** |
| Cursor `preCompact` | Provider documents `context_usage_percent` | Hook not installed. **Documented.** |
| Codex `thread/list` | Presence fallback | Merged into the same row list, not labeled as fallback. **Documented.** |

### Weakly implemented functionality

- Summary sentence is mutually exclusive: permission hides working; working hides counts. Flagged in `docs/session-redesign-research.md` on 2026-07-16 and still present. **Observed.**
- Cursor sessions cannot say "needs you." They can sit in thinking/usingTool while Cursor itself is blocked on an approval dialog. **Documented.**
- Claude model reporting is incomplete (SessionStart only, not guaranteed). Compact UI then looks like Claude has no model while Cursor does. **Documented** in Claude hooks; **Inferred** impact.
- Notifications click activates an app, not the session that asked. **Observed.**

### Weak UX

- Three Cursor rows in the same project look like three unrelated items.
- Model is the thing you now choose daily, and it is one expand-click away.
- Allowance answers "how much is left" and not "what should I use next."
- Failed exists, but there is no failed notification, so a crash can be missed if you never open the popover during the 15-second disconnect window. **Inferred** from resolver timings plus notification policy.

### Missing integrations

- Gemini CLI, Copilot, Warp, OpenCode, Kimi CLI: none. That is currently correct.
- Cursor Cloud Agents: user-level hooks do not run there. **Documented.**
- Git branch / worktree identity: only the directory basename. Tonight a Claude session showed as `caliber-5-5a-composition-d702c0` because that is the worktree folder name. **Observed.**

### Architectural constraints

Closed `AgentProvider`, latest-state files, no capability matrix, allowance adapters that are either full or absent.

### Conceptual / product-model problem

The app still treats **Codex, Claude, and Cursor as the same kind of thing**. They are not.

- Codex is a harness plus OpenAI models plus a subscription window.
- Claude Code is a harness plus Anthropic models plus 5h/weekly windows.
- Cursor is a harness that runs Grok, Composer, Claude, GPT, Gemini, Kimi, and others, against two Cursor usage pools.

Tonight a Claude session file contained `"model":"grok-4.6"` in a Caliber Wallet folder, with a Cursor file sharing the same hashed session id. **Observed.** That matches the documented Cursor "third-party skills can also load Claude Code hooks" limitation. The product model cannot tell harness from provider from model, so the UI cannot either.

---

## 5. The "Something Is Missing" Investigation

### The feeling, derived from the product

AgenticGlow is excellent at **monitoring**: here is the current state.

It is weak at **assistance**: here is what deserves you, why, and what you can do.

That is not a request for autonomy. It is the gap between a status LED and a copilot for attention.

### Spectrum

```text
monitor -> understand -> prioritize -> recommend -> act
   ^ today                 ^ missing        ^ light        ^ few, reliable
```

Today AgenticGlow lives at **monitor**, with two narrow act-hooks (open the app; notify permission/quota).

It should live at **understand + prioritize**, with **light recommend** and **only reliable act**.

It should not live at orchestration.

### Moments the current UI cannot complete

Using tonight's live files as a worked example. **Observed.**

| Question | What AgenticGlow can say | What is missing |
| --- | --- | --- |
| What is happening? | Cursor working. Claude session exists. | Three models in one repo. |
| What matters? | Permission first, if any. | Claude weekly at 1% matters more than a browsing row. |
| Why it matters? | 1% left, triangle on the caption. | Weekly exhausted means Claude Code is a bad continuation target. |
| What changed? | Latest phase only. | No "Claude weekly crossed 10% then 1%." |
| What needs me? | Permission notifications. | Cursor approvals are invisible. Failed is easy to miss. |
| What should I do next? | Click a row to jump. | "Continue in Cursor Grok or Codex; do not start a new Claude turn." |
| What is another agent doing? | Other rows, unsorted by repo. | No "these three share AgenticGlow." |
| Is it blocked? | `.permission` only. | Cursor blocked, stalled 30 min, waiting on you in the IDE. |
| Are limits a problem? | Percent bars. | Claude weekly 1% vs Codex 56% vs Cursor Grok pool. |
| Would another model be better? | Model hidden in expand. | Grok vs Sonnet vs Composer are already concurrent. |
| Can work continue elsewhere? | No. | Same cwd is on disk and unused. |
| What happened while I was away? | Whatever files remain, latest state. | No timeline. |
| How do the tools relate? | Three provider colors. | Harness vs model vs subscription pool. |

### Why this feels like "something is missing" rather than "I want more"

The original three questions are still the right questions. The environment outgrew the unit of analysis.

In June the unit was **a Codex or Claude session**.
In August the unit is **a piece of work**, executed by **a harness**, using **a model**, drawing from **a usage pool**, sometimes **in parallel with other harnesses in the same repo**.

AgenticGlow upgraded the session list (failed state, pulse, expand, tool icons, Cursor). It did not upgrade the unit of analysis.

The July 16 research doc already named the ambient-versus-dashboard trap and recommended staying a glancer. That recommendation is still right. The missing piece is not a Kanban board. It is **making the glance describe work, not just agents**.

---

## 6. Competitive and Adjacent Product Research

Research date: 2026-08-21. Prefer principles over copies.

The biggest change since the July 16 internal research: **this is no longer an empty category.** Several open-source Mac companions now overlap AgenticGlow. That does not mean copy them. It means the differentiated position is "the trustworthy native glancer," not "the first glancer."

### Direct Mac companions

| Product | What they optimize | Principle to learn | Principle to reject |
| --- | --- | --- | --- |
| [AgentBar](https://github.com/michalstrnadel/AgentBar) | Menu bar + island; per-provider identity; Approve/Deny from the bar | Surface the session that needs you most | Remote permission decisions away from the diff. v1 spec forbids this. |
| [rocky-notch](https://github.com/wescld/rocky-notch) | Notch companion across Claude, Codex, Grok, Cursor, Kimi | Honest per-provider capability disclosure | Chimes on every permission. Also: its README claims Cursor lacks `preToolUse`/`sessionStart`. **Observed** tonight those Cursor hooks *do* fire for AgenticGlow. Do not copy competitor capability tables blindly. |
| [cc-dashboard](https://github.com/heypandax/cc-dashboard) | Claude-only approval queue | Bounded trust ("allow for N minutes") is a real attention idea | Command-center layout. Temporary auto-approve from a third-party app is still driving the agent. |
| [AgentBuddy](https://github.com/techgocodingnow/agentbuddy) | Multi-CLI monitor + desktop pet | Documents which providers cannot report "needs input" | Mascot layer vs `PRODUCT.md` personality. |
| [CodexBar](https://codexbar.app) | Usage/quota menu bar + widgets | Burn vs remaining window, not a naked percent | Cookie/Full Disk Access scraping for Cursor and others. Larger privacy footprint than AgenticGlow should take. |
| [AgentSessions](https://github.com/jazzyalex/agent-sessions) | Session history + per-session quota runway | Which session is eating the window | Full transcript browsing. Directly opposes `docs/privacy.md`. |
| [Agent Island](https://agent-island.dev) | Notch state machine: idle / working / your-turn / stalled / auth / rate-limited | Named attention states with grace periods, close to AgenticGlow's 30-minute stale-active rule | Auto-resume ("OK" / continue) manufactures oversight. |
| [Tower Island](https://github.com/g535879/TowerIsland) | Notch control tower | Collapsed vs expanded | Remote-control for every agent |
| [Code Island](https://github.com/rifqiakrm/code-island) / [CodeIsland](https://github.com/wxtsky/CodeIsland) | 13-17 agents from the notch | Jump-to-tab precision | Fake parity across many tools |

**Proposed:** do not compete on coverage count, island chrome, or in-bar approval. Keep install/repair/remove, zero transcript storage, and native craft. That combination is still rare.

**Documented** user demand for this category: Codex desktop still has no "needs attention first" sort ([openai/codex#20817](https://github.com/openai/codex/issues/20817)), and commenters there already point at AgentSessions and Agent Island as stopgaps. AgenticGlow already sorts permission first. The remaining gap is saying *all* the true attention facts at once, including usage constraint and same-folder overlap.

### Harnesses themselves

| Product | Principle | For AgenticGlow |
| --- | --- | --- |
| Cursor Agents Window | List of local/cloud agents in the IDE | Do not rebuild this. Cursor already has it. Own the cross-harness glance Cursor cannot see. **Documented** limitation: Cursor does not prevent two agents writing the same files. |
| Claude Code Agent View | Lists *backgrounded top-level* sessions only; subagents stay nested. Peek panel answers prompts in-tool. **Documented** at [code.claude.com/docs/en/agent-view](https://code.claude.com/docs/en/agent-view.md). | Keep folding Task subagents. Keep permission *awareness*. Leave permission *decision* in Claude. `PermissionDenied` is worth a later yes/no, not a completeness chase. |
| Codex app-server | `thread/list`, `account/rateLimits/read` | Already used well. Do not decode transcripts. Filed Aug 2026 issues: sidebar floods with CLI/subagent sessions, no attention-first sort, subagents can silently drain weekly quota ([#20817](https://github.com/openai/codex/issues/20817), [#31127](https://github.com/openai/codex/issues/31127)). Learn: keep subagents folded; never promise per-subagent usage until Codex exposes it. |
| Warp Oz | Multi-harness control plane | Confirms everyone else is building a command center. Stay ambient. |
| GitHub Copilot | Enterprise Metrics API and session streaming | Admin-scoped. No per-user local API. Out of scope. |
| JetBrains Junie | Local `~/.junie/sessions/*/events.jsonl` | Same shape as existing adapters if ever added. Not a 2.0 requirement. |
| Xcode 26.3+ | Claude Agent and Codex as in-Xcode runtimes via MCP | Possible extra session surface. **Unverified** whether AgenticGlow hooks fire. |

### Adjacent attention systems

| Product | Principle |
| --- | --- |
| Linear Inbox / Triage | Separate "needs review" from "already in the workstream." Count stays small because unreviewed work is not mixed with active work. Snooze exists. **Documented** at [linear.app/docs/inbox](https://linear.app/docs/inbox). |
| Raycast | Fast actions from a thin surface. The menu is not the system of record. |
| macOS Activity Monitor | Processes are grouped and filterable; the menu extra (if any) is not the full window. Different depths for different questions. |
| Apple Live Activities | Minimal -> compact -> expanded, escalate only on real state change. Already the best metaphor for AgenticGlow. Named in the July 16 research. Still unused as an information architecture, except for expand-to-detail. |
| Apple notification interruption levels | Passive / Active / Time Sensitive / Critical. Permission should map to Time Sensitive, never Critical (special entitlement, safety-of-life). **Documented** in WWDC21 session 10091; still the 2026 model. |
| iStat Menus / MeterBar | Glance first, details on demand. Already cited in the July 1 menu-experience spec. |

### Observability / routers (do not copy)

Langfuse, LangSmith, OpenRouter Broadcast, Helicone, Braintrust: traces, tokens, evals, cost. They are for shipped LLM apps, not for a personal coding glancer.

**Principle:** those products prove that "token charts" are a different job. AgenticGlow should not become a local Langfuse.

Cursor's own usage model is now two pools (Cursor Models including Grok 4.6 / 4.5 / Composer 2.5, and Other Models at API rates). **Documented** at [cursor.com/docs/models-and-pricing](https://cursor.com/docs/models-and-pricing). That is the map AgenticGlow needs for recommendations, not a cost dashboard.

### Cursor hooks that AgenticGlow does not use yet

Official [cursor.com/docs/hooks](https://cursor.com/docs/hooks) currently documents, among others:

- `model` and `model_id` on the common payload. **Already mapped.**
- `preCompact` with `context_usage_percent`. **Not installed.**
- `subagentStart` / `subagentStop`. **Deliberately omitted** (would explode session count). **Documented** in `docs/integrations.md`.
- No `PermissionRequest` / `Notification` hook. **Documented.**

Claude Code now has a much larger hook surface (`PermissionDenied`, `SubagentStart`, `CwdChanged`, SessionStart `model`, etc.). **Documented** at [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks). AgenticGlow should add fields only when they improve glance or attention, not to chase completeness.

---

## 7. Multi-Provider and Multi-Model Opportunity

### Integration levels that make sense

| Level | Meaning | AgenticGlow should |
| --- | --- | --- |
| 1 Awareness | Know the name and that it exists | Yes, for models inside Cursor (Grok, Kimi, Gemini, GPT, Claude, Composer) |
| 2 Monitoring | Sessions, activity, limits, errors, state | Yes, per capability. Never fake missing fields. |
| 3 Interaction | Open / jump / supported operations | Yes, only where reliable (Codex window raise is the gold standard) |
| 4 Coordination | Relationships across harnesses | Yes, starting with same-repo / same-folder overlap |
| 5 Orchestration | Route or continue work across providers | **No**, not in 2.0. Fragile, duplicates Cursor/Codex, violates "do not alter agent behavior." |

### Recommended stance per surface

| Surface | Level | Notes |
| --- | --- | --- |
| Codex app / CLI | 3 | Hooks + app-server presence + usage + window raise |
| Claude Code app / CLI | 2-3 | Hooks + unofficial usage + generic activate. Exact window raise unsupported. |
| Cursor desktop | 2-3 | Official hooks. Jump to Cursor. No permission. No usage. Model yes. Context pressure possible via `preCompact`. |
| Cursor Cloud Agents | 1 at most | Hooks do not run. Do not scrape. |
| Models inside Cursor | 1-2 | Display and group. Do not invent a Grok provider. |
| Gemini CLI / Copilot / Warp / OpenCode / Kimi CLI | 1 until a documented, fail-open, metadata-only hook exists | Add as adapters, not peers of Codex |
| OpenRouter / LiteLLM | 0 | Wrong layer |

### Capability matrix (today)

```text
                 sessions  usage  model  attention  resume/jump  messages
Codex            yes       yes    partial  permission  window raise  no
Claude           yes       unofficial  partial  permission  app activate  no
Cursor desktop   yes       no     yes      no          app activate  no
Cursor cloud     no        no     no       no          no            no
Grok as harness  n/a       n/a    via Cursor  n/a      n/a           n/a
```

**Proposed:** this matrix should be a real type in Core, not a comment in docs. The UI should degrade: no usage row, not a 0% bar; no permission badge, not a silent "working" while Cursor is blocked.

---

## 8. Information Architecture Review

### What should dominate?

Not Agents. Not Providers. Not Models.

**Proposed primary object: Work.**

Work = a local project identity, initially `workingDirectory` (already collected), later optional git root if it can be derived without new permissions.

Sessions are instances of work.
Harness (Codex / Claude / Cursor) is how the instance is running.
Model is which brain is running it.
Task is the current phase label, not a first-class object yet (AgenticGlow does not store prompts).
Attention is the sort key, not the grouping key.

This matches how a developer actually thinks:

> "I am in AgenticGlow. Cursor Grok is reading, another Cursor session is on Sonnet, Composer is thinking. Claude weekly is dead. Codex still has room."

Not:

> "Here is a Cursor row, here is another Cursor row, here is a third Cursor row, here is a Claude row named after a worktree hash."

### How the popover should read

1. Attention, if any (needs you, failed, weekly exhausted).
2. Work groups for active overlap (same directory).
3. Remaining sessions, still urgency-sorted.
4. Allowance as decision support, still quieter.

Menu bar stays a rollup of attention, not a work list.

Settings/Setup stay configuration.

A later optional window, if ever, is for history and "while you were away," not for replacing the popover.

### Why not provider-first?

Tonight's live data already has Claude-colored identity on a Grok model. Provider-first would make that confusion load-bearing.

### Why not model-first?

Model without work is trivia. "Grok is working" is less useful than "Grok is in AgenticGlow."

---

## 9. Attention and Notification Model

### Keep

- Quiet when nothing needs you.
- Permission as the primary interrupt.
- Low-allowance badge, not a siren.
- Widget does not prompt (medium/large). Small may headline an attention count because that is its only job. **Documented.**

### Strengthen

Attention should be a first-class state, not only `SessionPhase`.

| Attention | Trigger | Surface |
| --- | --- | --- |
| Silent | working normally | Row pulse, colored icon |
| Notice | completed, reset | Brief row / icon celebration, no banner |
| Needs you | permission (Claude/Codex); failed; Cursor invisible-block is *not* inventable | Notification + icon + row |
| Constrained | window < 10% or exhausted | Existing badge + caption; add "this changes what you should use" in allowance copy |
| Collision | two+ active sessions, same cwd | Calm heads-up in popover, not a notification at first |
| Stale | active phase, no update for N minutes but under 30 min idle cutoff | Row hint, not a notification unless it crosses a higher threshold |

**Proposed:** do not add iMessage. Do not add sound beyond the system notification sound already available. Do not escalate on every tool call.

Cursor permission remains unsupported. The honest UX is "Cursor cannot tell AgenticGlow when it needs you," not a fake waiting state. **Documented** limitation; **Proposed** copy.

Failed should notify once, like permission. A 15-second row that nobody sees is not attention management. **Proposed.**

---

## 10. Session Intelligence

Unified session intelligence is valuable **if grouped by work**. A flat union of every provider's sessions will feel like clutter past ~6 rows. Tonight there were six files, three of them the same repo. **Observed.**

Fields worth showing, in compact vs expanded:

| Field | Compact | Expanded | Data today |
| --- | --- | --- | --- |
| Project / folder | Yes | Yes | Basename only |
| Harness | Color + name in a11y | Yes | Provider enum |
| Model | Yes, if known | Yes | Cursor strong; others partial |
| Phase / tool | Yes | Yes | Yes |
| Elapsed | Yes if active | Started + last updated | Yes |
| Needs you | Sort + icon | Note | Claude/Codex only |
| Same-repo mark | Yes if collision | List siblings | cwd exists, unused |
| Context pressure | Only if high | Percent | Cursor `preCompact` not installed |
| Branch | No | Only if cheap and local | Not collected |
| Task text | No | No | Would violate privacy |

**Proposed:** do not show CPU, tokens, confidence, or cost. Those are not in the privacy contract and are not needed for the glance.

---

## 11. Usage Intelligence

Percentages are necessary and insufficient.

Tonight: Claude weekly 1% left, Claude 5h 43% left resetting soon, Codex weekly 56% left, Cursor unknown. **Observed.**

Questions worth answering, all from data already fetched or honestly marked unknown:

| Question | Feasible now? |
| --- | --- |
| Which provider is constrained? | Yes. Claude weekly is. |
| When does it reset? | Yes. Already shown. |
| Did it just reset? | Partially. Weekly reset already celebrates. 5h reset does not. |
| Has unexpected usage occurred? | No, no history. A small ring of allowance snapshots would enable this. |
| Which provider is safest to continue with? | Partially. Codex 56% vs Claude 1% is obvious. Cursor is unknown and must stay unknown. |
| Can this task move? | Coordination, not usage. Same cwd is the tell. |
| Is a stronger model worth remaining allowance? | Not without a model catalog and pool map. Do not guess. |

**Proposed copy shape, not a chart:**

> Claude weekly 1% left (resets Sun). Codex 56% left. Cursor usage unknown.

If Claude is exhausted and a Cursor Grok session is already in that repo, a later recommendation can say Cursor Grok draws from a different pool than Claude Code. That sentence needs a static catalog, not live Cursor billing.

Do not scrape `cursor.com/dashboard`. **Documented** non-goal. CodexBar's cookie/Full Disk Access path is a caution, not a template.

Burn-rate charts (CodexBar, AgentSessions) are a useful *principle*: a percent without pace cannot answer "will this window die before reset." They are the wrong *feature* to copy. `tasks/lessons.md` already records that a weather-widget reference was about restyling existing percents, not adding pace math. Phase 1 should stay a sentence under the bars. A later ring of snapshots can support "unexpected burn" without becoming a charting app.

---

## 12. Cross-Agent Continuity

Realistically possible without a fragile system:

1. **Same-folder overlap.** Compare `workingDirectory` across active sessions. Tonight this would have grouped three Cursor models under AgenticGlow. **Observed** data; **Proposed** UI.
2. **Duplicate identity.** Same hashed session id appearing as both `claude` and `cursor` should collapse or flag "reported by two hook systems." **Observed** tonight on `sid_6f235ce1...`.
3. **Continuation hint, not handoff protocol.** If Claude is exhausted and the same cwd has a live Cursor or Codex session, say so. Do not copy transcripts. Do not start the other agent.
4. **Open the right app.** Keep Codex window raise. Improve Cursor/Claude only if a reliable, narrowly scoped mechanism exists. Do not take Accessibility.

Not realistically possible without becoming something else:

- "Continue this turn in Cursor using Grok" as an automated action.
- Conflict-free file locking across agents.
- Shared task objects across harnesses.
- Cloud-agent continuity.

Cursor itself disclaims write-conflict prevention. AgenticGlow can warn "two agents in this folder." That is enough, and nobody else is doing it well. The July 16 research already called this the unsolved gap. It is still unsolved, and the data to start is already on disk.

---

## 13. Provider Architecture

Current shape is a **shared normalizer with per-provider managers**. That is the right skeleton. It is not yet a platform.

**Observed special cases:**

- `HookDefinitionFactory.entry` vs `cursorEntry`
- `CursorHookPayload`
- `CodexSessionDiscovery`
- `CodexAllowanceAdapter` vs `ClaudeAllowanceAdapter` vs no Cursor adapter
- Setup view hard-codes three cards
- `AgentProvider.allCases` drives allowance rows, incident rows, widget providers

**Proposed:**

```text
HarnessAdapter
  id, displayName, color
  hookInstall: none | jsonFile(spec)
  events: set
  capabilities: CapabilitySet
  mapPayload(raw) -> NormalizedEvent?
  open(session) -> OpenAttempt
  usage: none | fetch()

CapabilitySet
  sessions, usage, model, permission, contextPressure,
  explicitFailure, windowRaise, cloudSessions
```

New harnesses become adapters. Models are not adapters. Models are metadata on sessions, plus an optional static catalog for pool hints (Cursor Models vs Other Models).

Graceful degradation is a UI requirement: hide unused sections, label unknowns, never draw 0% for "no API."

Feature flags: keep Cursor permission and Cursor usage off until the provider documents them. A flag that pretends they exist would be worse than absence.

---

## 14. Recommended One-Click Actions

Only actions that can be implemented reliably and safely.

| Action | Why | Reliability |
| --- | --- | --- |
| Open session / harness | Already the core loop | Codex high; others medium |
| Open popover from widget / shortcut | Already exists | High |
| Acknowledge / hide a failed or idle row | Already exists as Remove | High |
| Copy work context | Project name, cwd, harness, model, phase, last updated. No prompts. | High |
| Reveal in Finder | cwd is already stored | High |
| Refresh usage | Already exists | Codex/Claude |
| Open Codex / Claude / Cursor | Bundle IDs already known | High |

Do not build:

- Approve / deny permission
- Answer a pending question
- Terminate a stalled session
- Switch provider
- Prepare an automated handoff package that includes transcript
- iMessage
- Reveal a specific terminal tab unless a documented, scoped API exists (iTerm2 is a rabbit hole)

---

## 15. Opportunities Ranked by Impact

### Tier 1: Transformative

#### 1. Work identity (group by working directory)

- **Problem:** parallel sessions in one repo look unrelated.
- **Benefit:** the glance finally matches how work is done.
- **Complexity:** low-medium. Thread `workingDirectory` into `SessionSnapshot`, group in the popover.
- **Maintenance:** low.
- **Architecture:** small, correct.
- **Reliability:** high. Path comparison is local and already validated.
- **Provider dependency:** none.
- **UX:** high, if grouped only when overlap exists.
- **Confidence:** high.
- **Evidence:** Observed live tonight.

#### 2. Decision-shaped allowance, not just percentages

- **Problem:** 1% Claude weekly and 56% Codex are adjacent bars with no sentence.
- **Benefit:** "what can I keep using" becomes obvious.
- **Complexity:** low. Derived copy from existing `ProviderAllowance`.
- **Maintenance:** low. Cursor stays "unknown."
- **Architecture:** none beyond copy + maybe a comparator.
- **Reliability:** high if unknown is explicit.
- **Provider dependency:** none new.
- **UX:** high.
- **Confidence:** high.
- **Evidence:** Observed live tonight; Documented Cursor-usage gap.

#### 3. Honest capability model (harness vs model vs pool)

- **Problem:** Cursor looks like Claude/Codex. Models are buried. Claude-Grok misattribution can happen.
- **Benefit:** the product starts telling the truth about the 2026 toolchain.
- **Complexity:** medium. Catalog + capability set + compact model label + duplicate-hook collapse.
- **Maintenance:** medium (model names change). Keep the catalog small and best-effort.
- **Architecture:** this is the structural change everything else hangs on.
- **Reliability:** medium for Claude model; high for Cursor model.
- **Provider dependency:** Cursor `model_id` already flows.
- **UX:** high.
- **Confidence:** high that the distinction is the missing concept; medium on catalog freshness.
- **Evidence:** Observed live session files; Documented Cursor pricing pools.

### Tier 2: High value

| Item | Why | Complexity | Confidence |
| --- | --- | --- | --- |
| Summary that can state multiple truths | Permission + working + constrained usage at once | Low | High |
| Failed / stalled notification | Attention currently dies if the popover is closed | Low | High |
| Cursor `preCompact` context pressure, shown only when high | Unique signal, ignore until e.g. >= 80% | Low | Medium |
| Duplicate Claude+Cursor session collapse | Tonight's `sid_6f235ce1` pair | Low-medium | High that it happens |
| Same-repo collision mark | Unsolved elsewhere | Low given cwd | High |
| Tiny allowance snapshot ring (last N fetches) | Enables "unexpected burn" and "just reset" | Low-medium | Medium |
| Compact model slug on the row | Already in expanded detail | Trivial | High |

### Tier 3: Useful

- Codex 5h reset notice, not only weekly celebration.
- "Last event" already in Setup; surface last update on compact rows as a tooltip.
- Better Claude/Cursor activate if a narrow API appears.
- Optional history window, off by default.
- Static "Cursor Grok uses the Cursor Models pool" footnote when Grok is the active model.

### Tier 4: Experimental

- Explainable recommendations ("Claude weekly is gone, this folder already has Cursor Grok").
- "While you were away" digest from an append-only ring buffer.
- Gemini CLI / Copilot adapters at awareness or monitoring, only with documented hooks.
- Optional main window.
- Git branch via a local `rev-parse` in the helper working directory. Useful, easy to get wrong, not required for 2.0.

### Do not build

See section 16. Ranked here so it is not tempting.

---

## 16. What Not to Build

| Idea | Why not |
| --- | --- |
| Permission approve/deny from AgenticGlow, including "allow for N minutes" | v1 non-goal. Alters agent behavior. AgentBar and cc-dashboard already occupy this. The diff belongs in the harness. |
| Auto-resume / auto-send "continue" | Agent Island's move. Manufactures oversight. |
| Dynamic Island / notch control tower | Different product. Fights AgenticGlow's calm native identity. |
| 15-provider fake parity | Code Island's trap. Honesty dies. |
| Transcript / prompt / tool I/O display | Privacy contract. AgentSessions is the anti-reference. |
| Token, cost, and latency dashboards | Langfuse's job. |
| Burn-down charts as a primary UI | Useful math later; wrong default. Existing percent + one decision sentence first. |
| Agent orchestrator that routes tasks | Fragile, duplicates Cursor/Codex, high blast radius. |
| Expand cookie scraping past the disclosed Claude path | CodexBar's Full Disk Access / Safari cookie pattern. |
| iMessage alerts | Wrong channel, high annoyance, weak reliability. |
| Becoming an IDE or Agents Window | Cursor and Claude already have those. |
| Subagent rows for every Task tool | Documented omission, correct. Codex users are already drowning in undifferentiated subagent rows. |
| Cloud agent scraping | No hook, would be reverse engineering. |
| Mac App Store in this phase | Entitlements and sandbox would fight the helper/hooks design. |
| Charts of daily usage | Spec already excluded this in July 1. Still right. |
| Sound packs / mascots | AgentBar / AgentBuddy identity, not AgenticGlow's. |

Complexity must earn its place. Most of the above would make a beloved daily glancer into a noisier, less trusted app.

---

## 17. What AgenticGlow Is Missing

Not twenty features. Three underlying ideas.

### 1. It monitors agents. You think in work.

Sessions are the implementation unit. Projects, folders, and in-flight tasks are the mental unit. AgenticGlow already knows the folder and throws it away before the UI. Until sessions are instances of work, the app will always feel like a status LED strip rather than an understanding of the day.

### 2. It reports state. It does not triage state.

Many things can be true at once: Cursor is working, Claude weekly is gone, a session failed, two models are in one repo. The UI can only lead with one clause, and notifications only fire for permission and quota thresholds. Linear's insight applies: unreviewed need must be separated from ambient activity, or the glance becomes a list.

### 3. It still thinks provider = product.

Codex, Claude, and Cursor are not peers. Cursor is a harness. Grok and Sonnet are models. Claude weekly and the Cursor Models pool are different constraints. Until that split is first-class, every new integration will feel bolted on, and the "which tool should I use now" question will stay unanswered even when the numbers are on screen.

Solving these does not make AgenticGlow bigger. It makes the existing glance mean more.

---

## 18. AgenticGlow 2.0 Product Thesis

**AgenticGlow remains the calm, private, local status layer for AI coding work on a Mac.**

It evolves from "which agent is busy" to:

> What work is in motion, what needs me, and where I can continue.

### Core experience

Open nothing, know whether you are needed.
Open the popover, know which work is live, which model is on it, and which usage constraint changes the next move.
Click once to return to that harness.
Never inspect a prompt. Never drive the agent. Never pretend a provider can do what it cannot.

### Information hierarchy

1. Attention (needs you, failed, exhausted)
2. Work (folder / project), with sessions inside when they overlap
3. Harness + model as attributes
4. Allowance as continuation guidance
5. Configuration elsewhere

### Provider architecture

Harness adapters + capability matrix + model metadata. Models are not providers.

### Attention system

Quiet default. Permission and failure interrupt. Usage constrains. Collision informs. Cursor's missing permission hook is disclosed, not faked.

### Multi-model strategy

Understand models inside Cursor first, because that is already daily reality. Do not add Grok as a fourth `AgentProvider`. Add Gemini CLI or Copilot only as adapters with honest Level 1-2 support.

### Primary surfaces

Unchanged set. New meaning.

- Menu bar: attention rollup
- Popover: work + continuation
- Widget: passive state
- Notifications: needs you, failed, exhausted
- Settings/Setup: configuration
- Optional later: a history window, off by default

### Key workflows

1. Glance: am I needed?
2. Popover: what work is live, and is usage steering me?
3. Jump: return to the harness
4. Continue: if Claude is dry, keep going where capacity remains
5. Away: later, a short digest from retained metadata

### What stays unchanged

Privacy contract. Local-only. Fail-open hooks. Liquid Glass. Provider colors. Opt-in usage. No prompt storage. No accounts. Menu-bar-first. Craft bar for widgets and icons.

### What gets removed or simplified

- Mutually exclusive summary sentence
- Treating missing Cursor usage as a hole to fill with scraping
- Expanded detail as the only place a model exists
- Duplicate Claude+Cursor rows for one conversation

### What gets added

Work grouping, capability-honest UI, compact model, decision copy for allowance, same-repo mark, failed notification, optional context pressure, adapter matrix.

---

## 19. Phased Evolution Roadmap

### Phase 1 - Small changes, disproportionate value

Ship against data already in hand.

1. Put `workingDirectory` on `SessionSnapshot`.
2. Group or badge overlapping active sessions.
3. Show model on the compact row when present.
4. Rewrite the summary so it can say more than one true thing.
5. Add one continuation line under ALLOWANCE when a window is low or exhausted.
6. Notify on `.failed` once, matching permission.
7. Collapse or flag duplicate Claude/Cursor ids.
8. Disclose Cursor's missing permission and usage in Setup/UI, not only in docs.
9. If the compact row has no model slug, say "model unknown" rather than omitting the line. Cursor's own UI has been inconsistent about showing Grok names.
10. Audit permission notifications against Apple's Time Sensitive interruption level. Do not use Critical.

Acceptance: on a morning like tonight, the popover should make the AgenticGlow collision and the Claude weekly constraint obvious in under two seconds.

### Phase 2 - Structural improvements

1. `CapabilitySet` + harness adapter protocol.
2. Attention as a derived view over phase, usage, overlap, and staleness.
3. Small append-only ring: last events per session, last allowance snapshots.
4. Cursor `preCompact` installed observe-only, shown only at high pressure.
5. Static Cursor pool catalog for Grok/Composer vs Other Models, labeled as guidance.

Acceptance: adding a fourth harness does not require editing `SessionListView` color tables by hand. A missing capability stays visually absent.

### Phase 3 - Multi-provider expansion

Only after Phase 2.

- Gemini CLI / Copilot / others as Level 1-2 adapters if hooks are documented, metadata-only, and fail-open.
- Improve jump-to-session per harness only with a Codex-quality mechanism.
- Still no Cursor usage scrape.

### Phase 4 - Advanced, only if Phase 1-2 prove themselves

- "While you were away"
- Explainable recommendations with visible reasons
- Optional history window
- Git branch if it can be local, cheap, and honest
- Not: orchestration, permission remote-control, island UI

---

## 20. Open Questions

1. When Claude weekly is at 1% and Cursor Grok is already in the same repo, is the desired next action "keep using Cursor" or "stop and wait for reset"? **Unverified.** Phase 1 should not guess; it should state the constraint.
2. How often are duplicate Claude+Cursor rows from third-party skills vs real parallel Claude Code + Cursor? Tonight shows at least one duplicate. **Observed** once; rate unknown.
3. Should overlapping sessions notify, or only badge in the popover? **Proposed:** popover only, until it is missed in real use.
4. Is a history window wanted at all, or is a better popover enough? July 16 research bet on ambient + expand. This review agrees, with history optional later.
5. Will Anthropic ship a supported usage API, retiring the cookie? Revisit condition already **Documented**.
6. Will Cursor ship permission hooks or a local usage API? Until then, do not fake them.
7. Trademark / name clearance for "AgenticGlow" was flagged in the June 25 spec and is still an open product-risk item, not a UX item.
8. Do Claude Agent / Codex sessions launched inside Xcode 26.3+ fire the same hooks AgenticGlow already installs, or are they an invisible extra surface? **Unverified.**
9. Should `PermissionDenied` (Claude) inform `.failed` / blocked, or is inferred disconnect enough? **Proposed:** decide in Phase 2, do not install it just because the hook exists.

---

## 21. Final Recommendation

**EVOLVE WITH TARGETED STRUCTURAL CHANGES**

Not "keep evolving in the current direction." The current direction is excellent craft on a session glancer: Cursor as a third peer, widgets, icon polish, expand-to-detail. That work should be kept. It will not close the incomplete feeling, because the unit of analysis is still wrong.

Not "rethink the product model before adding features" in the sense of replacing AgenticGlow with a dashboard, island, or orchestrator. The product model of a calm local glancer is the asset. Rethink the *objects* inside it: work, harness, model, constraint. Then add almost nothing else.

The test for 2.0 is not a longer settings pane. It is whether, on a day like 2026-08-21, AgenticGlow can make this sentence obvious without opening Cursor, Claude, or a usage site:

> AgenticGlow has three models in it. Claude weekly is gone. Codex still has room. Nothing is waiting on you unless it can actually say so.

That is what the app is missing. Everything else is either in service of that sentence, or should not be built.

---

## Appendix: Evidence snapshot (2026-08-21 evening)

Live files under `~/Library/Application Support/AgenticGlow/`, plus the running app and hook configs. **Observed.** Prompts were not present; only metadata was read.

Runtime:

- `/Applications/AgenticGlow.app` 0.5.13-dev, running (PID observed during inspection)
- `AgenticGlowWidget.appex` running
- Helper at `~/Library/Application Support/AgenticGlow/bin/agenticglow-event`

Hooks (`--agenticglow-hook` present in all three):

- `~/.codex/hooks.json`: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PermissionRequest, Stop
- `~/.claude/settings.json`: those plus SessionEnd, Notification
- `~/.cursor/hooks.json`: sessionStart, sessionEnd, beforeSubmitPrompt, preToolUse, postToolUse, postToolUseFailure, stop

Sessions:

- Cursor / AgenticGlow / `grok-4.6` / Reading
- Cursor / AgenticGlow / `claude-sonnet-5-thinking-high` / Browsing
- Cursor / AgenticGlow / `composer-2.5-fast` / Thinking
- Cursor / Caliber Wallet-goal4-2 / `grok-4.6` / Completed
- Claude / Caliber Wallet-goal4-2 / `grok-4.6` / Thinking (same hashed session id as the Cursor row above)
- Claude / caliber-5-5a-composition-d702c0 / Completed / worktree path

Multiple Cursor sessions shared `sourceProcessID` 55151, matching the known shared-process staleness limit.

Allowance:

- Codex weekly: 44% used, 56% left, reset 2026-08-27
- Claude 5h: 57% used, 43% left, reset 2026-08-22 03:39 UTC
- Claude weekly: 99% used, 1% left, reset 2026-08-23; tracker marked `approachingLimit`
- Cursor: no cache file, as designed

This review did not rebuild the app. Source, docs, live session files, the running 0.5.13-dev install, and current provider documentation were sufficient for a product decision. A rebuild would not have changed the architectural findings.

---

# Adversarial Review of the Product Thesis

Date: 2026-08-21 (same evening, later pass)
Scope: research and decision only. No code was changed.
Method: treat the original thesis as a hypothesis and try to break it. Do not defend the earlier conclusion.

The claim under attack:

> AgenticGlow should primarily evolve into a provider-neutral, trustworthy native awareness and attention layer for AI-assisted development, rather than becoming a broader control plane, agent manager, or execution surface.

The earlier shorthand was:

> Trustworthy native glance, not more agents and not remote control.

This section preserves that conclusion so it can be compared: **original thesis → adversarial findings → revised thesis.**

Evidence labels are the same as above: **Observed**, **Documented**, **Inferred**, **Proposed**.

---

## A1. Attack on “trustworthy native glance”

The strongest case against glance-as-strategy is not that glance is ugly. It is that glance is becoming a feature of the harnesses themselves, and a standalone product that only glances will look unfinished next to surfaces that glance *and* resolve.

### Glanceability is not enough to sustain a standalone product

**Documented:** Claude Code Agent View, launched 2026-05-11 as a research preview, is already the sentence AgenticGlow wants to own, inside Claude: “See at a glance which agents are waiting on you, which are still working, and which are done,” plus peek-and-reply without attaching. Source: [claude.com/blog/agent-view-in-claude-code](https://claude.com/blog/agent-view-in-claude-code) and [code.claude.com/docs/en/agent-view](https://code.claude.com/docs/en/agent-view).

**Documented:** Cursor 3 Agents Window, generally available since 2026-04-02, is a full agent-first workspace: multi-repo list, local/cloud/SSH, worktrees, diffs, PR management, local-to-cloud handoff. Source: [cursor.com/docs/agent/agents-window](https://cursor.com/docs/agent/agents-window).

**Observed tonight, after the original review:** four Cursor sessions were simultaneously thinking in `/Volumes/Liquid/2DaMax Development/AgenticGlow` (`grok-4.6` twice, `claude-sonnet-5-thinking-high`, `composer-2.5-fast`). Claude weekly was still **1% left**. Codex weekly was **54% left**. `workingDirectory` was on every session file. `SessionResolver` still dropped it before `SessionSnapshot`. The popover can still only show four unrelated Cursor rows.

If the user is already inside Cursor, Agents Window answers “what is happening in Cursor.” If they are already inside Claude, Agent View answers “what needs me in Claude.” AgenticGlow’s remaining job is only the sentence neither of those products can say:

> Four models are in AgenticGlow. Claude weekly is gone. Codex still has room. Nothing in Cursor can tell AgenticGlow it needs you.

That is a real job. It is a thinner job than the original review implied. A glance that cannot complete the next inch of that sentence will feel like a status LED next to products that already include the next inch.

### Monitoring-only products get commoditized

**Documented** third-party companions now ship glance *plus* resolution as the default pitch:

| Product | What they sell | Traction signal | Source |
| --- | --- | --- | --- |
| AgentBar | Live status **and** Allow / Always / Deny from the menu bar | 5 GitHub stars | [github.com/michalstrnadel/AgentBar](https://github.com/michalstrnadel/AgentBar) |
| Rocky | Notch/menu-bar monitor **and** one-click approve/deny | Public repo, multi-agent | [github.com/wescld/rocky-notch](https://github.com/wescld/rocky-notch) |
| DevIsland | Notch monitor **and** approval proxy **and** Fleet Radar (worktree, path overlap) | 4 stars | [github.com/nangchang/DevIsland](https://github.com/nangchang/DevIsland) |
| NotchBar | Notch control surface, approve/reject hotkeys, optional file locking | Public repo | [github.com/lukataylo/NotchBar](https://github.com/lukataylo/NotchBar) |
| Agent Deck | TUI command center: switch, fork, worktrees, conductor | 760 stars | [github.com/asheshgoplani/agent-deck](https://github.com/asheshgoplani/agent-deck) |
| AgentSessions | History + quota runway + transcripts | 522 stars (self-reported in Codex #20817) | [github.com/jazzyalex/agent-sessions](https://github.com/jazzyalex/agent-sessions) |
| Agents Elements | Native inventory/control center for Claude + Codex skills, sessions, cost | Public release 2026-06-14 | [github.com/LasaleFamine/agents-elements](https://github.com/LasaleFamine/agents-elements) |

The original review said the differentiated position is “the trustworthy native glancer, not the first glancer.” That is still a position. It is no longer an empty category, and the newer entrants are not competing on glance quality. They are competing on **closing the loop**.

Star counts are weak evidence of product-market fit. They are enough to show the category’s gravity: awareness-only is the smaller story.

### Harnesses will absorb intra-harness awareness

This is the existential argument the original review underweighted.

1. Claude Agent View already lists every background session across projects, groups by state, pins “needs you” at the top, notifies on need/finish/fail, and lets the user reply in place. **Documented.**
2. Cursor Agents Window already lists local and cloud agents across repos. **Documented.** AgenticGlow still cannot see Cursor Cloud Agents. **Documented** in `docs/integrations.md`.
3. Codex Desktop still lacks attention-first sidebar sort. Issue [openai/codex#20817](https://github.com/openai/codex/issues/20817) remains **open** (created 2026-05-02, last update 2026-06-17). Related issues keep appearing (#27436, #29297, #33318, #33323). **Documented.** Codex is the one harness where AgenticGlow’s attention sort is still ahead.
4. Xcode 26.3 embeds Claude Agent and Codex via MCP. **Documented** at [developer.apple.com/videos/play/tech-talks/111428](https://developer.apple.com/videos/play/tech-talks/111428/). Unverified whether AgenticGlow hooks fire for those sessions.

**Inferred:** if the user spends most of the day in one harness, that harness’s own list will beat a third-party glance for *that* harness. AgenticGlow only stays necessary when the user regularly crosses harnesses, or when the harness list is bad (Codex today).

Tonight’s usage is the first case: Cursor is the primary harness, four models, no Codex sessions. **Observed.** A Cursor-only user can already open Agents Window. AgenticGlow’s unique remaining facts are Claude weekly 1% and the duplicate Claude+Cursor row, not the Cursor session list.

### If agents get better at surfacing their own attention, what remains?

What remains is **cross-harness truth** and **constraint truth**:

- same folder, two harnesses
- Claude weekly dead, Codex weekly alive, Cursor usage unknown
- Cursor cannot report permission
- a Claude hook and a Cursor hook reporting the same hashed id

Those are not attention intelligence in the abstract. They are **work identity + honest capability holes**. The original review named both, then still titled the strategy “attention layer.” That title is too small for the remaining job and too large for what a glance can honestly own.

### A separate application is still justified, but only for the cross-harness job

A separate app is justified when the user is *not* looking at Claude or Cursor.

It is not justified as a second Agents Window.

**Proposed:** the standalone-app assumption survives only if AgenticGlow says something the focused harness cannot. The moment it becomes “your Cursor sessions, again, in the menu bar,” first-party absorption wins.

### Awareness-only creates a context-switch tax

The current loop is: notice icon → open popover → click row → hope the right window rises → resolve there.

For Codex, window raise is real. **Observed.**
For Claude and Cursor, activate is generic. **Observed.**
Notification clicks activate a bundle ID, not the session. **Observed.**

Claude Agent View’s peek-and-reply exists because “see the block, then attach to type three characters” was too expensive. **Documented.** Users will eventually expect the surface that *detects* a problem to *finish* the cheap problems. The original review treated that expectation as a category error. It is a product-completeness demand.

That does not mean AgenticGlow should become Agent View. It means a glance that never completes the last inch will keep feeling unfinished.

### Strongest case that the original conclusion is too narrow

The original conclusion optimized for AgenticGlow’s current architecture (hooks in, metadata out, no agent behavior changed) and then named that architecture a strategy.

The market is not asking for a prettier LED. First-party products are shipping **awareness + reply + dispatch**. Third-party products are shipping **awareness + approve**. The category that is growing is hybrid. Pure awareness is the layer most likely to be absorbed for free.

---

## A2. “Not remote control” is the right fear and the wrong boundary

The original review treated approve/deny, resume, stop, reply, and handoff as one pile: remote control. That pile is too coarse.

### Definitions

**Remote control:** AgenticGlow becomes a client of the agent. It changes what the agent does: approve a tool, send a prompt, start a session, interrupt a turn, switch a model, route a task.

**Contextual resolution:** AgenticGlow finishes the awareness loop using facts it already has, without driving the agent: open the right session, copy the work context, reveal the folder, hide a stale row, refresh usage, say which constraint changes the next move.

These are not the same thing. The original v1 spec forbade the first. **Documented** in `docs/superpowers/specs/2026-06-25-agenticglow-design.md`: “Monitoring must not alter agent behavior” and “Approving or denying permissions from AgenticGlow” is excluded.

### Capability-by-capability

| Capability | User value | Feasibility | Security | Reliability | Provider support | Maintenance | Identity |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Approve / deny pending requests | High when the user is away from the terminal | Claude: PermissionRequest hook can return `decision.behavior` allow/deny. **Documented** at [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks). Codex: app-server sends `item/commandExecution/requestApproval` and expects `accept` / `decline`. **Documented** in [codex-rs/app-server/README.md](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md). Cursor: no permission hook. **Documented.** | High. Approving a command without the diff is how accidents happen. AgentBar already shows `Bash: git push` in a tooltip. | Medium-low. Claude hook decisions have been ignored ([anthropics/claude-code#19298](https://github.com/anthropics/claude-code/issues/19298)). Silent PermissionRequest hooks in `/remote-control` default to deny ([#54582](https://github.com/anthropics/claude-code/issues/54582)). | Claude yes, Codex yes if AgenticGlow becomes an app-server client, Cursor no | High. You become a permission proxy. Fail-open is no longer free. | **Violates.** This is remote control. |
| Respond to simple agent questions | High in Claude Agent View | Requires transcript or question text | High. Stores or displays prompt content. | Medium | Claude Agent View already does this in-product. **Documented.** | High | **Violates** privacy contract (`docs/privacy.md`). |
| Resume sessions | Medium | Codex `thread/resume` is documented. Agents Elements already advertises `codex resume` recall. | Medium. Resume is not destructive, but it is driving the harness. | Medium. Codex desktop resume/archive is currently buggy ([#25713](https://github.com/openai/codex/issues/25713), [#25779](https://github.com/openai/codex/issues/25779)). | Codex strongest | Medium | **Gray.** Useful; starts turning AgenticGlow into a Codex client. |
| Stop / interrupt | Medium-high when a run is clearly wrong | Codex `turn/interrupt` is documented. Claude Agent View has stop. | Medium. Stopping the wrong thread is real. | Medium | Codex yes, Claude in-product, Cursor in-product | Medium | **Gray.** Contextual if the user is looking at a failed/runaway row; remote control if it becomes a primary verb. |
| Restart failed work | Medium | No clean cross-provider API | Medium | Low | None as a common verb | High | Remote control. |
| Open exact workspace / session | High | Codex window raise exists. Claude/Cursor are generic activate. **Observed.** | Low | Codex high, others medium | Partial | Low | **Strengthens.** This is the gold-standard last inch. |
| Switch provider | Low-medium | No API. Would launch another app with no shared context. | Low | Low | None | High | Remote control / orchestration. |
| Transfer work between providers | Low as automation, medium as a hint | Hint can use cwd + allowance. Transfer needs transcripts. | High if transcripts move | Low for automation | None | High | Hint strengthens. Transfer violates. |
| Initiate an agent | Medium | Launching `claude --bg` or Cursor is possible, not reliable as a product verb | Medium | Low | Partial | High | Control plane. |
| Queue a task | Medium | Requires a task object AgenticGlow does not have | Medium | Low | None | High | Orchestration. |
| Prepare a handoff | Medium | Copy project, cwd, harness, model, phase. No prompts. | Low | High | Local metadata already exists | Low | **Strengthens.** |
| Continue with another model | Medium as copy, high as action | Action is orchestration | Medium | Low | Cursor already does this inside Cursor | High | Copy strengthens. Action violates. |
| Trigger validation | Medium | Could run `xcodebuild` or tests in cwd | Medium | Medium | Independent of providers | Medium | Creeps toward project runner. Defer. |
| Execute predefined safe actions | High if the set stays tiny | Reveal in Finder, copy context, refresh usage, open harness | Low | High | Already local | Low | **Strengthens.** |

### Where the boundary actually belongs

**Proposed boundary:**

1. AgenticGlow may complete the last inch of *awareness*: jump, reveal, copy, hide, refresh, state the constraint.
2. AgenticGlow may not become a client that changes agent behavior: approve, deny, reply, auto-resume, start, route.
3. Interrupt/stop is the only gray verb worth revisiting later, and only for Codex, and only if `turn/interrupt` can be aimed at the exact thread the row represents. Not in the next phase.

The original “not remote control” rule should stay. The original “almost no actions” rule should not. Refusing last-inch resolution is how a loved glancer keeps feeling incomplete.

John already declined system-wide Accessibility as too broad. **Documented** in `tasks/todo.md`. That is evidence the control-plane path is not just a brand risk. It is a trust risk this user has already rejected.

---

## A3. Attention intelligence is not the missing ingredient

The original review said the missing layer was understanding the significance of telemetry. That is partly true and mostly a misdiagnosis.

Tonight’s facts already have significance. Claude weekly 1% is significant. Four models in one repo are significant. A Claude row attributed to `grok-4.6` with a Cursor twin is significant. The app has those facts and does not use them. **Observed.** That is not a missing intelligence model. That is unused structure.

### Alternative explanations, ranked against the current product

| Rank | Explanation | Fit | Why |
| --- | --- | --- | --- |
| 1 | Missing project / work identity | Best | `workingDirectory` is on disk and dropped at `SessionResolver` line 85-98. Four Cursor rows in AgenticGlow still render as four peers. **Observed.** |
| 2 | Missing last-inch resolution | Best-after-work | The only verb is “activate source app.” Notification clicks miss the session. Claude/Cursor jump is generic. The user sees the problem, then hunts. **Observed.** |
| 3 | Missing honest capability / constraint picture | Strong | Cursor looks like a third Codex/Claude. Compact rows hide model. Allowance has no continuation sentence. Claude-Grok misattribution still present. **Observed.** |
| 4 | Missing history / continuity | Medium | Latest-state files, 24h retention, completed rows last 8s. “While you were away” is impossible. Real, not the daily hole. **Observed.** |
| 5 | Missing workspace awareness (git, builds, tests, Xcode) | Medium-low | Worktree folder `caliber-5-5a-composition-d702c0` is the current stand-in for a branch. Useful later. Easy to get wrong. Not why the popover feels thin tonight. **Observed.** |
| 6 | Missing task object | Tempting, weaker | “Redesign Moodpaper onboarding” would be more meaningful than session 924. AgenticGlow refuses to store prompts. **Documented** in `docs/privacy.md`. A task object without task text is a user-maintained label. That is a new product. |
| 7 | Missing execution / control | Overstated | Approve/deny would close some loops. Cursor cannot participate. Claude Agent View already closes Claude loops. The incomplete feeling tonight is four working Cursor rows and a dead Claude week, not a stuck permission. **Observed.** |
| 8 | Missing model catalog / cost / context limits | Partial | Model slugs are already on Cursor events and hidden. A catalog helps pool hints. Cost dashboards are Langfuse’s job. |
| 9 | Missing orchestration | Poor fit | Warp Oz and Agent Deck exist for this. John’s live pattern is parallel local sessions, not a DAG of cloud workers. |
| 10 | Missing automation of repetitive situations | Poor fit | Nothing in the live data says “this happens every morning, automate it.” |
| 11 | Missing product depth (a bigger primary window) | Poor fit | A dashboard would make the same session list larger. July 16 research already rejected this. Still right. |

**Inferred:** the “something is missing” feeling is not “the app needs a smarter attention score.” It is “the app knows which folder and which model and which constraint, and still talks like a session LED.”

Attention should remain the *sort key*. It should not remain the *product thesis*.

---

## A4. Competitive analysis, revisited to weaken the original

The original competitive table was directionally right and strategically soft. It treated first-party dashboards as “do not rebuild this” and third-party islands as “reject their chrome.” Both are correct tactics. They understate the convergence.

### What the market is actually doing

```text
Awareness-only          Hybrid                  Control / orchestration
     |                      |                            |
AgenticGlow            AgentBar / Rocky          Warp Oz
CodexBar (usage)       DevIsland / NotchBar      Agent Deck
                       Agent View (Claude)       Cursor Agents Window
                       Codex mobile approvals    Claude remote-control
```

**Documented convergence:**

- **Integrated IDE / harness experiences (strongest force).** Cursor Agents Window and Claude Agent View are not adjacent. They are the default future of intra-harness awareness *and* control.
- **Control-plane companions.** AgentBar, Rocky, DevIsland, NotchBar all treat approve/deny as the reason to exist. DevIsland’s Fleet Radar already claims worktree state and changed-path overlap, the “unique gap” the original review reserved for AgenticGlow.
- **Orchestration.** Warp Oz (now also called Automation Platform) is explicit: “2026 will be the year of agent orchestration.” Source: Warp launch materials and [docs.warp.dev/platform](https://docs.warp.dev/platform/). Agent Deck’s Conductor is the open-source version of the same idea.
- **Official remote control.** Claude Code remote control from the Claude iOS/Android app is first-party. **Documented** at [code.claude.com/docs/en/remote-control](https://code.claude.com/docs/en/remote-control) and [code.claude.com/docs/en/mobile](https://code.claude.com/docs/en/mobile). Users are already filing bugs because permission prompts do *not* reliably reach the phone ([#28427](https://github.com/anthropics/claude-code/issues/28427), [#29438](https://github.com/anthropics/claude-code/issues/29438)). Demand is for resolution away from the terminal, not for a prettier local LED.
- **Inventory / cost control centers.** Agents Elements scans `~/.claude` and `~/.codex` for skills, sessions, MCP, plugins, and spend. Different job, same gravity: “one place for everything the agents installed.”
- **Enterprise OS control plane.** Jamf AI Governance (GA 2026-06-30) discovers and policies Claude Code, Claude Desktop, and Codex on Mac fleets. **Documented** at [jamf.com](https://www.jamf.com/resources/press-releases/jamf-launches-ai-governance-a-first-of-its-kind-native-ai-control-plane-for-mac/). Not a consumer competitor. Proof that “control plane” is the phrase the rest of the industry reached for.

### Category verdict

The category is **not** converging on awareness tools.

It is converging on **C + B**: integrated harness experiences, with a secondary market of hybrid glance-and-approve companions. Orchestration is a third, louder market (Warp, Agent Deck) that AgenticGlow should not enter.

If AgenticGlow aims at pure A (awareness), it is aiming at the layer first parties are most motivated to absorb, and the layer third parties treat as table stakes.

The only durable A-position is **cross-harness work truth with honest holes**. That is narrower than “attention layer” and deeper than “glance.”

---

## A5. Standalone-app assumption

| Form | Verdict | Why |
| --- | --- | --- |
| Menu bar first | **Keep** | The only form that can interrupt without becoming a workspace. Matches how this Mac already uses it. **Observed.** |
| Full desktop app as primary | **No** | Competes with Agents Window and Agent View on their home field. |
| Xcode extension | **No for now** | Helps only Apple-platform work. Unverified hook coverage. Splits the product. |
| Cursor / VS Code extension | **No** | Would see only Cursor. Destroys the cross-harness reason to exist. |
| Background service + many surfaces | **Already true** | App + widget + notifications. Enough. |
| Control Center module | **No** | No documented consumer API worth the cost. |
| Widget-centric | **Keep as secondary** | Already shipped. Passive glance. Do not make it the product. |
| Notification-first | **No** | Permission + quota are enough. Notification-first becomes AgentBar. |
| Web companion | **No** | Conflicts with local-only. |
| Mobile companion | **No** | Claude already ships official remote control. Codex has mobile approval flows. Building a third remote would be the control-plane product. |

**Proposed:** the current form is still optimal. The missing work is meaning inside the existing surfaces, not a new chassis.

---

## A6. Attack on the multi-provider abstraction

The original recommended:

```text
harness → provider → model → project → task → session
```

### Where it fails

1. **Users never need to see it.** Nobody thinks “harness Cursor, provider xAI, model grok-4.6, project AgenticGlow, task unknown, session sid_…”. They think “Grok is in AgenticGlow.” **Inferred** from tonight’s live files.
2. **Cursor blurs the layers on purpose.** Cursor is the harness, the subscription, the product, and the place models run. Treating it as a peer of Claude Code is already misleading. Treating Grok as a fourth `AgentProvider` would be worse. The original review got this right. The six-layer model still over-explains it.
3. **Normalization creates false equivalence.** A Cursor “thinking” row and a Claude “thinking” row look like the same kind of fact. Only Claude can become “needs you.” Only Codex/Claude can show usage. **Observed** and **Documented.**
4. **Providers expose insufficient data for a common model.** Cursor has no permission hook and no local usage API. Claude model is incomplete. Codex model is partial. A shared schema that pretends these fields are optional decorations will keep lying.
5. **Task cannot be first-class without prompt text.** Privacy forbids the obvious implementation. **Documented.**
6. **A capability graph is more honest than a common data model.** “This adapter can: sessions, model, jump. Cannot: permission, usage.” That is what the UI needs. Not a universal Session object that sometimes has holes.

### Keep, simplify, or replace?

**Proposed:** keep a harness adapter + `CapabilitySet` internally. Do not expose the six-layer ontology. In the UI, show:

```text
Work (folder / project)
  session = harness + model + phase
  constraint = usage pool, if known
```

Task stays out until there is a user-authored label or a provider-supplied title that is not a prompt.

---

## A7. Project is a stronger center than attention

The original review already said the primary object should be Work. The executive thesis still led with “attention layer.” Those two statements are in tension. The adversarial pass resolves it in favor of work.

Tonight, again:

```text
AgenticGlow
  Cursor  grok-4.6                    thinking
  Cursor  claude-sonnet-5-thinking-high thinking
  Cursor  composer-2.5-fast           thinking
  Cursor  grok-4.6                    thinking (newer id)

Caliber Wallet-goal4-2
  Claude  grok-4.6                    thinking  (same sid as Cursor row)
  Cursor  grok-4.6                    completed

caliber-5-5a-composition-d702c0
  Claude  (model unknown)             completed
```

**Observed.**

A developer does not care that “Claude session 924 is active.” They care that Caliber work is being reported twice, and that AgenticGlow has four models in it while Claude weekly is dead.

Project-centric grouping would have made that obvious in under two seconds. Attention scoring would have sorted four “thinking” rows and still looked like a LED strip.

**Proposed:** project/work is the missing center. Attention is how you sort inside it. The original review half-said this and then packaged the strategy as attention intelligence. That packaging should be dropped.

---

## A8. Task is the most meaningful object and the least reliable one

A persistent task that survives Claude → Cursor → Codex would be the most human object:

```text
Task: Redesign Moodpaper onboarding
Started: Claude Code + Opus
Continued: Cursor + Grok
Review: Codex
Status: implementation complete, validation pending
```

What would be required:

- a stable identity that is not a session id
- some description of the work
- links to sessions, repos, branches
- a place to store that across 24h file churn

What that costs:

- prompt or title storage, or a user-maintained inbox
- a second information architecture
- pressure to start, resume, and hand off (orchestration)

**Proposed:** do not make Task the center. It would solve the poetry of the missing feeling and create a product AgenticGlow is not. If a provider later exposes a non-prompt task title (Claude Agent View already generates row summaries with a Haiku-class model, **Documented**), show it as a label on a session, not as a new graph.

Work (folder) is the reliable proxy for “what am I trying to accomplish” without storing the work itself.

---

## A9. Simplicity is both a principle and an excuse

### Where “keep it simple” is blocking useful depth

- Threading `workingDirectory` into the snapshot
- Grouping overlap
- Model on the compact row
- A summary that can say two true things
- A continuation sentence under allowance
- Failed notification
- Copy work context / Reveal in Finder
- Disclosing Cursor’s missing permission instead of looking peer-equal

Those are not feature creep. They are the current product telling the truth. The original review listed most of them, then still framed the strategy as restraint. Restraint is right for control-plane verbs. It is an excuse if it delays work identity.

### Where complexity would actually harm the product

- Approve / deny / auto-resume
- Notch / island chrome
- Fake 15-provider parity
- Transcripts, token charts, cost heatmaps
- Becoming an Agents Window
- Task orchestration
- Mobile remote control
- Git/build/test as a second product

### Boundary

**Valuable depth:** make the existing glance describe work, constraints, and the next reliable action.

**Feature creep:** make AgenticGlow the place work is *done*.

---

## A10. Existential risks (12–24 months)

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Claude Agent View becomes the default Claude surface, with notifications and peek-and-reply | High. Already shipped as research preview. **Documented.** | High for Claude-only days. Low for cross-harness days. | Own the sentence Claude cannot say: other harnesses, usage comparison, Cursor holes. |
| Cursor Agents Window absorbs Cursor session lists | High. Already GA. **Documented.** | High. Tonight is a Cursor-primary machine. | Do not rebuild Agents Window. Show Claude/Codex constraints and same-folder overlap Cursor cannot see. |
| Codex ships attention-first sidebar sort | Medium. #20817 open, demand is loud, desktop is currently unstable. **Documented.** | High for Codex-only days. | Stay ahead on cross-harness + usage. Do not bet the product on Codex remaining blind. |
| Claude official remote control + mobile push for permissions | High demand, medium reliability. **Documented** issues. | Medium. Steals the “I walked away” job. | Stay local, honest, cross-harness. Do not build a phone app. |
| Xcode in-IDE Claude/Codex | Medium. 26.3 already shipped. Hook coverage unverified. | Medium for Apple-platform work. | Treat as another possible session surface, not a new product. |
| OS-level consumer agent manager | Low. Jamf is enterprise governance, not a menu-bar glancer. WWDC26 MLX work is local-model serving. **Documented.** | High if Apple ships it. | Unlikely in 12 months. Revisit if a system extra appears. |
| Standardized provider session APIs / MCP Tasks | Medium for tools, low for session glance. MCP 2026-07-28 is a tool protocol, not a session bus. **Documented.** | Medium. Could make adapters easier, not obsolete. | CapabilitySet becomes more valuable if APIs converge. |
| Free companions bundle AgenticGlow-like glance + approve | High. Already happening. Traction still small except Agent Deck / AgentSessions. | Medium. They will look more complete. | Do not copy approve. Win on trust, craft, work identity, honest holes. |
| Built-in usage reporting improves | Medium. Codex already has local rate limits. Claude cookie path is unofficial. Cursor still undocumented locally. | Medium. Allowance bars become less unique. | Keep the *comparison and continuation* sentence, not the bar. |

**What stays valuable even if every provider improves:**

1. Cross-harness overlap in one folder.
2. Honest “this harness cannot report that.”
3. Subscription constraints compared across products.
4. A calm native interrupt that is not a terminal dashboard and not a notch toy.
5. Privacy that AgentSessions and CodexBar are willing to give up.

Those are not “attention intelligence.” They are **cross-harness work truth**.

---

## A11. Competing product futures

### Future A: Native Attention Layer

Stay at glance, notifications, smarter ranking.

- Value: lowest complexity, keeps the brand.
- Differentiation: shrinking. Agent View and Agents Window already glance.
- Daily usefulness: high for Codex-blind days, low for Cursor-only days.
- Risk: the incomplete feeling never goes away.
- Defensibility: weak.

### Future B: Agent Control Plane

Approvals, replies, resume, stop, routing, dispatch.

- Value: highest raw demand. This is what AgentBar / Rocky / Agent View / Oz are selling.
- Differentiation: none. Late and worse-capitalized.
- Security / reliability: poor. Hook decisions are flaky. Cursor cannot participate. Codex app-server is a moving target.
- Identity: destroyed.
- Risk of bloat: certain.

### Future C: Project Intelligence Layer

Center on projects, branches, builds, tests, agents, progress.

- Value: matches how the user thinks. Tonight’s data wants this.
- Differentiation: stronger than A, if kept local and metadata-only.
- Complexity: medium, then high if git/builds/tests become first-class.
- Risk: becomes a tiny IDE. Git/build/test are a second product.
- Daily usefulness: high if it stops at folder + overlap + constraint. Lower if it chases Xcode health.

### Future D: Hybrid (recommended)

Awareness layer, work as the object, bounded last-inch actions, honest capabilities.

- Value: closes the incomplete feeling without changing what AgenticGlow is.
- Differentiation: the only native product that can say the cross-harness sentence and jump back.
- Complexity: low-medium if the action set stays tiny.
- Security: unchanged if approve/deny stay out.
- Defensibility: the combination of privacy, fail-open, craft, and work identity is still rare.
- Risk of bloat: real if “last inch” becomes “one more verb.”

### Future E (considered, rejected): Task Orchestrator

Persistent tasks across providers.

Rejected because it requires prompt-like text, duplicates Warp/Agent Deck/Cursor, and turns AgenticGlow into a router.

### Scores (1-5, higher is better except Complexity/Bloat)

| | A Attention | B Control | C Project | D Hybrid |
| --- | --- | --- | --- | --- |
| Product value | 3 | 4 | 4 | 5 |
| Differentiation | 2 | 1 | 3 | 4 |
| User fit (this Mac) | 3 | 2 | 4 | 5 |
| Complexity (lower better) | 5 | 1 | 3 | 4 |
| Reliability | 4 | 2 | 3 | 4 |
| Security | 5 | 1 | 4 | 5 |
| Maintainability | 4 | 1 | 3 | 4 |
| Defensibility | 2 | 1 | 3 | 4 |
| Daily usefulness | 3 | 3 | 4 | 5 |
| Bloat risk (lower better) | 5 | 1 | 2 | 3 |

---

## A12. Pre-mortem

### If we follow the original recommendation (polished attention-intelligence layer)

Assume 2028. The product is irrelevant. Why:

1. **Absorbed by the home screen.** Cursor Agents Window and Claude Agent View became good enough that a third list of the same sessions felt like clutter. The user quit opening the popover.
2. **Codex shipped the sort.** #20817 landed. The last harness where AgenticGlow was clearly ahead disappeared. Nobody needed a menu bar to find the blocked chat.
3. **The bounce tax won.** Every useful alert still required another app. The user trained themselves to ignore AgenticGlow and watch the harness that could resolve the alert.
4. **A free hybrid looked complete.** Rocky or DevIsland added approve/deny and folder overlap. Even when the approvals were unsafe, the product *felt* finished. AgenticGlow felt like a theme.
5. **The unit stayed wrong.** Sessions were still the object. Four models in one repo still looked like four LEDs. The incomplete feeling was never a missing badge. It was a missing sentence.

Hidden assumptions this exposes:

- That “better ranking of the same objects” is enough.
- That first parties will stay bad at intra-harness awareness.
- That users will accept a detector that cannot finish cheap loops.
- That simplicity is the same thing as completeness.

### If we follow the strongest alternative (hybrid: work + last-inch, no control plane)

Assume 2028. That product failed. Why:

1. **Last-inch crept into control.** Reveal and copy were not enough. Approve/deny shipped “just for Claude.” A silent hook denied a remote-control session. Trust died in one incident.
2. **Work identity needed git.** Folder grouping was ambiguous across worktrees. Branch/build were added. The popover became a project dashboard. The glance died.
3. **Cursor remained a black box.** No permission, no usage. The honest holes looked like a broken integration. The user blamed AgenticGlow, not Cursor.
4. **Task objects arrived anyway.** Someone stored titles that were basically prompts. The privacy contract became marketing.
5. **The cross-harness user disappeared.** The owner standardized on Cursor. Agents Window was enough. AgenticGlow’s remaining value was a Claude usage bar, and Anthropic finally shipped an official one.

Hidden assumptions this exposes:

- That the user will keep a multi-harness life.
- That Cursor’s missing APIs will stay forgiveable if disclosed.
- That a tiny action set will stay tiny.
- That folder is a good enough proxy for work.

---

## A13. Decision tests

Use these against the current product and any prototype. They distinguish strategies.

1. **Bounce test.** If the user sees an alert in AgenticGlow and immediately opens another app, is the next action something AgenticGlow could have done *without driving the agent*? If yes, that is a missing last-inch action. If no (they needed the diff), that is healthy separation.
2. **One-action test.** If most valuable alerts resolve with one low-risk, local, reversible action (jump, reveal, copy, hide, refresh), that action belongs in AgenticGlow. If they resolve with a behavior change (approve, send, start), they do not.
3. **Object test.** After five seconds in the popover, can the user name the *work* in motion, or only the *agents*? If only agents, the IA is still wrong.
4. **Cursor-only test.** On a day with only Cursor sessions, does AgenticGlow still say something Agents Window cannot (constraint, overlap with Claude/Codex, honest “Cursor cannot report permission”)? If not, the product is a duplicate.
5. **Claude-only test.** Same, versus Agent View.
6. **Constraint test.** When one usage pool is exhausted and another is not, does the glance change the next move without recommending a specific model? If it stays a pair of bars, usage is still decoration.
7. **False-equivalence test.** Can a new user tell that Cursor rows cannot “need you”? If not, the common model is lying.
8. **Duplicate-hook test.** When the same hashed id appears as Claude and Cursor, does the UI collapse or explain, or show two truths as two agents?
9. **Away test.** After 30 minutes away, can the user reconstruct what mattered, or only the latest phase of whoever is still alive?
10. **Verb budget test.** If a prototype adds a third verb beyond jump / reveal-or-copy / hide, it is probably becoming a control plane. Stop and re-justify.

---

## A14. Original roadmap, re-scored

| Original recommendation | Verdict | Why |
| --- | --- | --- |
| Put `workingDirectory` on `SessionSnapshot` | **KEEP** | Strongest unused fact. Still unused tonight. |
| Group / badge overlapping sessions | **KEEP** | This is the product. |
| Model on the compact row | **KEEP** | Already collected. Hidden. |
| Summary that can say more than one true thing | **KEEP** | Still mutually exclusive. |
| Continuation line under allowance | **KEEP** | Decision support, not a chart. |
| Notify on `.failed` | **KEEP** | Attention currently dies if the popover is closed. |
| Collapse duplicate Claude/Cursor ids | **KEEP** | Still present tonight (`sid_6f235ce1`). |
| Disclose Cursor missing permission/usage | **KEEP** | Honesty is the capability model. |
| “Model unknown” rather than omit | **KEEP** | Claude worktree row tonight has no model. |
| Time Sensitive for permission, never Critical | **KEEP** | Still correct. |
| `CapabilitySet` + harness adapter | **KEEP** | Internal. Do not show the ontology. |
| Attention as a derived view over phase/usage/overlap | **MODIFY** | Keep as sort key. Do not make it the thesis. Work is the grouping key. |
| Append-only ring of events / allowance snapshots | **DEFER** | Useful for “unexpected burn” and away-digest. Not the incomplete feeling. |
| Cursor `preCompact` when high | **KEEP** | Cheap, unique, ignore until high. |
| Static Cursor pool catalog | **KEEP** | Guidance, labeled as such. |
| Gemini / Copilot adapters | **DEFER** | After the current three tell the truth. |
| Jump-to-session improvements | **KEEP / RAISE** | Last-inch. Codex-quality mechanisms only. |
| “While you were away” | **DEFER** | After work identity exists, or it is a diary of LEDs. |
| Explainable recommendations | **MODIFY** | Constraint sentences only. No “use Grok now.” |
| Optional history window | **DEFER** | Still optional. |
| Git branch | **DEFER** | Worktrees already leak into folder names. Easy to get wrong. |
| Approve / deny | **REMOVE** (already excluded) | Reinforced. Hook unreliability + identity. |
| Auto-resume | **REMOVE** | Reinforced. |
| Island / notch | **REMOVE** | Reinforced. |
| Orchestration / start / route / transfer | **REMOVE** | Reinforced. |
| Attention intelligence as the 2.0 center | **REPLACE** | Replace with work identity + last-inch resolution + honest constraints. |
| Copy work context / Reveal in Finder | **KEEP / RAISE** | Original listed these as one-click actions. They belong in Phase 1, not as extras. |

---

## A15. Did the original thesis survive?

### SURVIVED WITH IMPORTANT MODIFICATIONS

The original thesis tried hardest to protect AgenticGlow from becoming a control plane. That protection was correct and should stay.

It was wrong about what the remaining product *is*.

### 1. What this pass tried hardest to falsify

That “trustworthy native glance / attention layer” is the right primary evolution, and that almost all interaction is a category error.

### 2. Evidence that challenged the original thesis

- Claude Agent View and Cursor Agents Window already ship glance + resolution in-product. **Documented.**
- Third-party companions treat approve/deny as the product. **Documented.**
- Codex app-server already has resume, interrupt, and approval RPC. **Documented.** Technical feasibility of a control plane is higher than the original implied. That makes the identity choice sharper, not easier.
- Tonight’s live state is a work problem and a constraint problem, not an attention-ranking problem. **Observed.**
- `workingDirectory` is still dropped. The original named this and still led with attention. **Observed.**
- Official Claude remote control is the “I walked away” product. **Documented.**

### 3. Evidence that strengthened it

- Cursor still cannot report permission or usage. A control plane would be Claude/Codex-only and would lie about parity. **Documented.**
- PermissionRequest hooks are unreliable and unsafe as a third-party proxy. **Documented.**
- John already refused broad Accessibility. **Documented.**
- Codex desktop session management is currently unstable. Becoming a Codex client is a reliability trap. **Documented.**
- AgentBar / DevIsland traction is still tiny. Control-from-the-bar is not a proven winner. **Documented.**
- Privacy and fail-open are still rare. AgentSessions and CodexBar show the path not to take. **Documented.**
- Cross-harness overlap remains unsolved by first parties. **Inferred**, still no counterexample.

### 4. What changed

- Center of gravity: **work**, not attention.
- Action boundary: last-inch resolution is in; remote control stays out.
- Competitive reading: the market is converging on hybrid and harness-native control, not awareness tools.
- “Provider-neutral” is an internal adapter strategy, not a UI promise of sameness.
- Attention intelligence is a sort function, not the missing ingredient.

### 5. What did not change

- Do not become an orchestrator, island, or Agents Window.
- Do not approve/deny, store prompts, scrape Cursor usage, or fake missing capabilities.
- Stay local, menu-bar-first, fail-open, native.
- Cursor remains a harness, not a fourth peer of Claude/Codex.
- Phase 1 still starts with data already on disk.

### 6. Strongest product direction now

**Future D, stated plainly:**

AgenticGlow stays the calm local awareness layer. It organizes around **work**, sorts by **attention**, tells the truth about **capabilities and constraints**, and offers a few **reliable last-inch actions**. It does not drive the agent.

---

## The Missing Thing, Reconsidered

Why can AgenticGlow be something to love and use every day, and still feel incomplete?

Not because it needs more agents. Not because it needs a control plane. Not because it needs a smarter attention score.

Two root causes, maybe a third.

### 1. It watches sessions. Daily work is a folder full of overlapping models.

That is why four Cursor rows in AgenticGlow still feel like a strip of LEDs. The app already knows the folder and throws it away. Solving this would make the popover describe the day. Do not solve it by building a project-management app, a git client, or a task database.

### 2. It can detect a problem and cannot finish the cheap next inch.

The only verb is “activate something nearby.” Codex raise is the exception that proves the rule. Claude Agent View exists because detection without resolution feels unfinished. The right last inch for AgenticGlow is jump, reveal, copy, hide, and a constraint sentence, not approve/deny. Do not solve this by becoming the agent’s remote.

### 3. (Secondary) It still presents unequal systems as equal rows.

Cursor cannot need you and cannot show usage. Claude weekly 1% is a different kind of fact from “Composer is thinking.” Until the UI can say that without shame, every new integration will feel bolted on. Do not solve this with a six-layer ontology in the popover.

Attention intelligence is how you sort those facts. It is not the thing that is missing.
