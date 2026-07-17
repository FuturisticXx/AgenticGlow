# Session Experience Research: Making AgenticGlow the Best Agent Session Manager on macOS

Date: 2026-07-16
Status: research complete, no implementation started

This document is the output of a deep research pass on AgenticGlow's Session UI: current-state code audit, HCI/attention research, Apple design principles, and competitive analysis against Claude Code, Cursor, Warp, Devin, and others. It ends with a prioritized roadmap. Nothing in this doc has been built yet.

---

## 1. Executive summary

AgenticGlow Session today is a **menu-bar-only ambient status glancer**: one `NSStatusItem`, one 360x420 popover, one flat list of session rows. Total session-facing code is about 2,800 lines across 19 Swift files. There is no dashboard, no history, no drill-down, no grouping, and each row shows exactly four things: an icon, a project name, a one-line action label, and (sometimes) an elapsed timer.

Every competitor researched (Cursor's Agents Window, Claude Code's Agent View, Devin's Kanban board, Warp's agent panes) has converged on a **list-of-agents dashboard** with named states and inline approval. AgenticGlow is the most minimal tool in the category, by a wide margin.

That minimalism is not automatically a weakness. It's AgenticGlow's actual differentiator: nobody else has built a good ambient glancer, because everybody else is building a command center. The research below supports a specific strategic position: **AgenticGlow should become the best ambient glancer in the category, and add an optional escalation tier for power users, rather than rebuild itself as a Cursor-style dashboard.** Apple's own Live Activities model (minimal -> compact -> expanded, escalating only on real state change) is a close structural match for this and gives a concrete design pattern to build against, not just a metaphor.

The critique below is genuinely brutal in places (duplicated status-color logic that can drift, an accessibility gap that hides elapsed time from VoiceOver, zero per-row animation, no distinction between "blocked/failed" and "cleanly disconnected"). None of it requires a rebuild. Most of the highest-value fixes are small, surgical changes to files that already exist.

---

## 2. Current Session critique (component by component)

Source: full code read of `Sources/AgenticGlowApp/MenuBar/*` and `Sources/AgenticGlowCore/{State,Events,Status,Notifications}/*`.

### SessionListView.swift (291 lines) — the popover itself
- **Purpose:** the entire session screen. One summary sentence, an incident strip, the session list, a divider, allowance bars, a gear menu.
- **Strength:** correctly keeps the popover lean; no tabs, no nested navigation to get lost in.
- **Weakness:** the `summary` line can only say one of three mutually exclusive things ("N need you" *or* "X and Y working" *or* "N sessions"). A user with 1 session needing approval and 2 still working only ever sees the approval sentence — the working count silently disappears. That's a real information loss, not just a copy nitpick.
- **Missing:** no way to sort, filter, group by provider, or search. Fine at 3 sessions; falls over at 15.
- **Unused space:** none, really — it's already tight. The gap is information density per row, not chrome.

### SessionRowView.swift (106 lines) — the only "card"
- It is not a card. No background, no border, no shadow of its own — it's a bare `HStack` inside the popover's shared glass surface. That's actually fine for a compact tier (cards-within-cards read as visual noise at this density), but it means there is currently zero visual distinction between "a session" and "a menu item."
- **Fields shown:** status icon, project name, `"{label} · {surface}"` detail line, elapsed timer (only while `.thinking`/`.usingTool`). That's it.
- **Fields collected but never shown:** `sessionID`, `sourceBundleID`, `updatedAt`. A user has no way to see "last updated 2 minutes ago" even though the data already exists on the model.
- **Interaction:** click activates the source app; right-click offers "Remove" (only when idle/disconnected/completed/permission — you can't remove a running row, which is correct). There is no drill-down, no NavigationLink, no sheet — this is the *only* interaction surface a row has.
- **Real gap:** the `elapsed` `Text` is explicitly `.accessibilityHidden(true)` (line 28). Sighted users see how long a session has been running; VoiceOver users get nothing. That's not a stylistic choice, it's a coverage hole.

### Status/health system — `SessionPhase` (6 states, no explicit failure)
```swift
enum SessionPhase { case idle, thinking, usingTool, permission, completed, disconnected }
```
- There is **no `.failed`/`.error` state**. A crashed or killed agent process is inferred as `.disconnected` — visually and semantically identical to a session that quit cleanly. A user cannot tell "it finished and closed" from "it died mid-task" without leaving the app.
- **Duplicated, drifting mappings.** `SessionRowView` and `StatusPresentation` (the menu-bar icon) each hand-roll their own icon/color table for the same six phases, and they don't agree: the row uses `sparkle` for both thinking and using-a-tool (no distinction), the menu bar uses `circle.hexagongrid`; the row uses `circle` for idle, the menu bar uses `circle.hexagongrid` again. Same semantic state, two different icons, defined in two different files. This is exactly the kind of thing that silently drifts further apart with every future change unless it's unified once.
- **Data the UI can't use even though it exists:** `ToolCategory` (Reading/Editing/Searching/Browsing/Running command/Delegating) is a real enum in the model layer, but it gets collapsed into a plain `String` label before `SessionSnapshot` ever sees it. The row can't render a per-action icon (edit vs. read vs. run) even though the backend already classifies the action — it's one small plumbing change away, not a new feature.

### Notification system — permission-only
- Only one thing triggers a system notification: a session newly entering `.permission`, plus allowance/quota threshold crossings. **A session that fails gets no notification at all** — because there's no failed state to notify on (see above).
- The menu bar badge dot is single-purpose (low allowance only); permission-needed count is communicated via plain text in the popover title, not a badge. Two different attention mechanisms for two different "needs you" situations, inconsistent with each other.

### Animation — all motion lives on the menu bar icon, none on rows
- The icon animation system (rotation, provider cross-fade, permission dissolve, celebration bounce) is genuinely sophisticated: hand-rolled 30fps clock-driven rendering (chosen deliberately after SF Symbol effects caused stutter when swapping tinted images), Reduce-Motion-aware, tuned so the cross-fade never reads as "all-alert" (capped at 80% color share).
- But **individual session rows have zero animation.** A row that's actively `.thinking` looks pixel-identical to a row that's been idle for an hour, aside from a small icon glyph difference. The only "something is happening" signal in the entire app lives on the menu bar icon, not next to the specific session that's actually active. This is a real, fixable gap — not a design philosophy choice, since Apple's own guidance (Live Activities, Dynamic Island) treats the per-item glanceable state as the primary signal, with the system-level indicator as a rollup.
- **Reduce Motion bug — correction (2026-07-16):** this report originally claimed `model.reduceMotion` is read once at `AppModel.init` and never re-observed. That was wrong: the research pass only audited `AppModel.swift` and missed `AppDelegate.swift`, where `ReduceMotionObserver` (line 427) already observes `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` live and keeps `model.reduceMotion` current, with passing tests. No fix was needed; verified during Task 4 implementation before writing any code.

### Dashboard / aggregate stats — doesn't exist
`ResolvedSessions` already computes `activeCount`, `permissionCount`, `activeProviders` — but every one of those numbers is consumed only to build the single summary sentence. None of it is ever rendered as a stat grid, a count badge per state, or anything resembling "3 running, 1 blocked, 2 done." The data pipeline for a real overview already exists; only the view doesn't.

### Timeline / history — doesn't exist
`SessionStateStore` persists exactly one JSON file per session, **overwritten in place** on every update. There is no append-only log. A session's prior actions are gone the instant a new event arrives. Even a small ring buffer (last 5 events) would let a user answer "what did this agent just do" without needing full replay infrastructure.

---

## 3. Research findings

### Human attention (Colin Ware's pre-attentive attributes; NN/g "Visibility of System Status")
- Pre-attentive processing (color, motion, size, orientation) resolves in 50-500ms, before conscious attention — but it is not purely bottom-up. Studies of peripheral change-detection show physically salient changes are still frequently *missed* when attention isn't already partially allocated there. Motion has a real edge in peripheral vision (magnocellular pathway is fast and motion-sensitive), but "motion always wins" is not supported.
- Practical read for AgenticGlow: reserve strong pre-attentive signals (motion, saturated color, size) for states that are both rare and actionable. Spending that signal on routine "still running fine" states trains the eye to ignore it — the same mechanism behind alert fatigue in SOC dashboards (see below).

### Apple design principles
- **Liquid Glass** (WWDC25, current across macOS/iOS 26): a translucent material meant to create depth/hierarchy between controls and content — AgenticGlow already uses this correctly (`LiquidGlassSurface.swift`, `GlassAppearance.swift`), including Reduce Transparency handling.
- **Live Activities / Dynamic Island model**: three escalating tiers — minimal, compact, expanded — where the *system*, not the user, decides when to escalate based on real state change. This is the single most directly-applicable Apple pattern for AgenticGlow's card design (see §8).
- **Progress indicators**: Apple's HIG explicitly prefers determinate over indeterminate whenever duration/step-count is knowable, because it lets people gauge time-to-completion, and warns against swapping spinner-for-bar mid-task.
- **Menu bar extras**: must stay monochrome/template by default; AgenticGlow's decision to bake per-provider color into a rendered image (rather than fight the system's template-flattening) is the documented, correct workaround, not a hack.

### Competitive analysis
| Product | Multi-agent pattern | Notable gap |
|---|---|---|
| Claude Code | Agent View lists every session (main + subagents); permission prompts are scoped and named per subagent | — |
| Cursor 3.0 | Agents Window — sidebar of all local/cloud agents, up to 8 parallel | explicitly does not merge output or prevent write conflicts between agents on the same file |
| Devin | Kanban board (in progress / blocked / ready for review); approval friction scales with model confidence | — |
| Warp | Vertical tabs/pane-stacking, positions itself as "a dashboard for an orchestra of agents" | — |
| OpenHands | Community explicitly requesting agent-status dashboarding as a missing feature | unclear agent state is a known, filed complaint |

**The one gap nobody has solved:** cross-agent conflict awareness — two agents touching the same repo/file at once. Cursor disclaims it outright. This is a real, evidence-backed opportunity for AgenticGlow to own, since it already has the process/session metadata needed to detect "two active sessions, same working directory."

### Professional monitoring dashboards (Kubernetes/K9s/Lens, SOC/NOC, CI dashboards)
Recurring pattern across all three domains: **(1)** group/roll up by shared cause so the top-level "things needing attention" count stays small, **(2)** keep the default view lean, push detail behind drill-down, **(3)** reserve strong visual weight for genuinely actionable states, **(4)** compact per-item glyphs (status dot, small trend) rather than full detail inline. SOC literature cites 70-85% alert-volume reduction from correlation/grouping alone in well-tuned deployments — this is the strongest evidence-backed argument for AgenticGlow's rollup-badge idea in §9.

### Accessibility
- WCAG 2.1: color must never be the sole carrier of status — pair with icon shape and text label. AgenticGlow already does this reasonably well for phase (icon + implicit label), less well for the permission-vs-low-allowance distinction (yellow dot vs. orange badge, both "attention," easy to conflate).
- Color-blind-safe pairing guidance favors blue/orange over red/green — AgenticGlow's actual palette (Claude burnt-orange, Codex azure, yellow=permission, green=completed, gray=disconnected) is already close to safe, but the *duplicated* color definitions (§2) mean this safety property isn't centrally guaranteed.
- Reduced-motion guidance: don't just kill a meaningful animation, replace it with a non-motion equivalent (solid-fill change, dissolve, highlight fade) that still communicates the state. AgenticGlow's `PopoverAura` already does exactly this correctly; per-row activity indicators (once added) should follow the same pattern from day one.

---

## 4. UX recommendations (see also §13/§14 roadmap)

1. Unify status-to-icon/color mapping into one shared source of truth consumed by both the row and the menu bar icon. Kills the drift risk in §2 outright.
2. Add an explicit failure/error phase, distinct from a clean disconnect. This is the single highest-value data-model change — almost everything else about "attention" downstream depends on being able to tell "it broke" from "it finished."
3. Give the active row its own subtle motion (not just the menu bar icon), Reduce-Motion-safe from the start.
4. Surface `ToolCategory` on the row (data already exists) so a user can tell "editing" from "running a command" from "reading" at a glance, via icon, without reading the label text.
5. Fix the Reduce Motion live-observation bug.
6. Un-hide the elapsed timer from VoiceOver; add `.accessibilityAddTraits(.updatesFrequently)`.
7. Replace the single-clause summary sentence with a structure that can report more than one true thing at once (e.g., "3 sessions · 1 needs you · 2 working" instead of only the highest-priority clause).

---

## 5. Information architecture

Keep the current two-tier structure (menu bar icon = ambient / popover = glanceable list) and add a third tier only on deliberate escalation (hover or click), matching Apple's Live Activity model exactly:

- **Minimal** — the menu bar icon. Answers one question: does anything need me, right now, yes or no. (Already exists, well-built.)
- **Compact** — the popover row list. Answers: what's running, what needs me, roughly how long. (Exists; needs the fixes in §4.)
- **Expanded** — reached by hover or click on a specific row, not shown by default. Answers: everything currently known about this one session (repo, branch, surface, last tool, last-updated timestamp). Does not require new data capture — everything in the mockup below is already on `SessionSnapshot` or one hop away in `NormalizedEvent`.

This keeps the popover's core promise (glanceable, not a dashboard) while giving power users a real detail view without adding a fourth screen.

---

## 6. Attention system proposal

Escalation should be driven by *state category*, not raw event volume:

| Tier | Trigger | Visual weight |
|---|---|---|
| Quiet | running normally (thinking/using tool) | small provider-colored glyph + subtle live-activity motion on that row only |
| Notice | completed, low allowance | single calm color change, no motion, auto-collapses after a few seconds (already true for `.completed`) |
| Attention | permission needed | current yellow treatment, scoped to that row, named in the notification (already correct) |
| Alert | failed/error (new state, §2) | the one state allowed a stronger visual (border-strength color, not full-row red fill) — reserved because it's rare, per §3's pre-attentive research |

The rule that makes this work: **only one state (failure) gets the "loud" treatment**, and it's rare by construction. Everything currently classified as "needs attention" in the code (`permission`) stays exactly as calm as it is today — it's already well-tuned, per the research in §3.

---

## 7. Agent card redesign

See the rendered mockup above (`agenticglow_session_card_redesign`) for the compact-tier and expanded-tier visuals.

**Fields evaluated from the prompt's full list, against what AgenticGlow's hook-derived data model can actually populate today:**

| Field | Available now? | Verdict |
|---|---|---|
| Project name, current task/action, model provider, elapsed time, tool category, surface (CLI/IDE), last-updated timestamp | Yes — already on `SessionSnapshot`/`NormalizedEvent`, some just not wired to the view | Add to compact/expanded tiers |
| Repo path, branch, working directory | Partially — `sourceBundleID` exists; repo/branch would need the hook payload to include `git rev-parse` output, which it doesn't today | Expanded tier only, after a small hook-payload addition |
| CPU/memory usage, context-window usage, cost/tokens, confidence, risk score, dependency chain, message count, quality score | No — none of this is in the current hook event schema for Claude Code or Codex | Do not fabricate placeholder UI for these; verify with each provider's hook/telemetry docs before promising them |
| Blocked reason, waiting-on-user, waiting-on-agent | Structurally close — this is what the proposed `.failed`/`.blocked` phase split should carry as an associated string | Add alongside the phase-model change in §4 |

Recommendation: build the compact and expanded tiers from data that already exists (huge amount of unused signal, per §2), and treat CPU/memory/confidence/cost as a distinct, separately-scoped research task — they require new data capture from the hook integration itself, not just new UI.

---

## 8. Session overview redesign

Given the current app deliberately has no dashboard, the recommendation is **not** to build a Cursor/Devin-style Kanban board. Instead:

- Fix the summary sentence (§4.7) so it reports every true state at once, using the `ResolvedSessions` counts that already exist but are currently discarded after building one clause.
- Add the rollup-badge pattern from SOC research (§3) once session count exceeds ~5-8 rows: collapse same-provider/same-state sessions under a "3 more working" disclosure rather than scrolling a long flat list.
- Leave a genuine multi-window "mission control" dashboard as a long-term, optional feature (§14) rather than default behavior — it competes on a different axis (active command center) than AgenticGlow's actual strength (ambient glancer).

---

## 9. Motion and animation recommendations

- Keep all existing menu-bar-icon animation as-is — it's well-built and Reduce-Motion-correct.
- Add one new animation: a subtle per-row indicator (e.g., a slow opacity breathe on the status glyph, not the whole row) for the specific session that's actively thinking/using a tool. Must ship with a Reduce-Motion-safe static alternative from day one (a solid-fill glyph, matching the pattern `PopoverAura` already uses correctly).
- Fix the Reduce Motion live-observation bug (§2) before adding any new motion — otherwise the new animation inherits the same staleness bug.
- Do not add animation to `.completed`/`.idle` rows — per §3's attention research, motion should stay reserved for "actively happening" and "needs you," not routine states.

---

## 10. Accessibility review

- **Confirmed gap:** elapsed timer hidden from VoiceOver (§2) — fix by exposing it via `accessibilityValue` alongside the existing label, not by removing `.accessibilityHidden` from the raw `Text` (which would double-announce).
- **Confirmed gap:** Reduce Motion read once at launch, not observed live (§2).
- **Good, keep:** row icon correctly hidden from VoiceOver with all status meaning carried in the composed label string — this is the right pattern (icon-hidden, text-carries-meaning) and should be the template for any new UI (the proposed failure state, tool-category icon, etc. all need the same treatment).
- **Good, keep:** allowance section's spoken strings (`AllowancePresentation.spoken`) are more thorough than the session row's — use that file as the reference quality bar when writing accessibility strings for new fields.
- **New requirement:** any new per-row animation must degrade to a non-motion equivalent under Reduce Motion (§9), and any new color (e.g., a failure-state red) must be paired with an icon shape and text label per WCAG, not stand alone.

---

## 11. Performance recommendations

The current architecture (poll-driven `SessionResolver`, `LazyVStack` in a `ScrollView`, single-file-per-session persistence) is already reasonably scalable for the 3-15 session range AgenticGlow is actually used at. Two things to verify (not yet confirmed, flag for a future check) before scaling toward 25-50+ sessions:
- `SessionStateStore` reads/writes one JSON file per session on every update — confirm this doesn't become I/O-bound at high session counts; if it does, batching writes or moving to a single append-log would be the fix, not a UI change.
- `LazyVStack` inside a fixed `maxHeight: 300` `ScrollView` should already handle large lists efficiently since SwiftUI lazily renders offscreen rows — no changes indicated unless profiling shows otherwise.

No changes recommended here without first profiling at realistic scale — this section is a "watch for it," not a prescribed fix.

---

## 12. Innovative ideas not currently found in competitor products

- **Cross-session conflict flag** (§3): detect when two active sessions share a working directory/repo and surface it as a distinct, calm "heads up" state — something every competitor researched either lacks or explicitly disclaims.
- **Escalation-tier card** (§5/§7) matching Apple's own Live Activity model exactly, applied to a desktop menu-bar context — none of the researched competitors (all of which are IDE panels or full windows) use this glanceable/expand-on-demand pattern; they default to always-expanded dashboards.
- **Failure state visually distinct from clean disconnect** (§2/§4) — a small, obvious gap in every phase-modeling approach seen in the competitive research too; worth confirming whether Claude Code/Codex's own UIs make this distinction before assuming AgenticGlow would be first.

---

## 13. Low-risk improvements (quick wins)

Small, surgical, single-file-scoped changes:

1. Unify the row/menu-bar status-to-icon/color mapping into one shared table (kills the duplication in `SessionRowView` + `StatusPresentation`).
2. Fix Reduce Motion to observe live instead of reading once at launch.
3. Expose elapsed time to VoiceOver via `accessibilityValue`.
4. Wire `ToolCategory` through `SessionSnapshot` to the row so per-action icons become possible.
5. Show `updatedAt` as a relative "last updated" string, at minimum in a tooltip.
6. Rewrite the summary sentence to report all true states, not just the highest-priority one.

Risk: low. All touch existing, already-tested files; none require new data capture or new UI screens.

## 14. Medium-effort work

1. Add the `.failed`/`.blocked` phase (with an associated reason string) to `SessionPhase`, threading it through `HookNormalizer`/`SessionResolver`, and give it the one "loud" visual treatment per §6.
2. Add per-row live-activity motion for actively-working sessions (§9), Reduce-Motion-safe from the start.
3. Build the expanded-tier hover/click detail view (§5/§7) from data that already exists on the model.
4. Add the rollup-badge pattern once session count exceeds ~5-8 (§8).
5. Cross-session conflict detection (§12) — needs a working-directory/repo comparison across active sessions, which the existing `SessionSnapshot`/`sourceBundleID` data likely supports but should be verified against what path data actually reaches the hook payload today.

Risk: moderate. Touches the core phase enum, which several files depend on — needs the failure-state work done once, carefully, with tests, rather than as several partial changes.

## 15. Long-term / vision

1. Optional, off-by-default "mission control" window for power users running many concurrent agents — a genuine escalation past the popover, not a replacement for it.
2. Lightweight append-only event history per session (even a small ring buffer) to answer "what did this agent just do" without full replay infrastructure.
3. Richer per-session telemetry (CPU/memory/context-window usage/cost) — contingent on what Claude Code's and Codex's hook/telemetry surfaces actually expose; needs its own research/verification pass before committing to it, since today's hook payload doesn't carry it.

---

## 16. Risks and trade-offs

- **Adding a failure state** touches a widely-depended-on enum (`SessionPhase`) — every consumer (`SessionRowView`, `StatusPresentation`, `AgentNotificationService`, `SessionResolver`'s priority sort) needs updating together, or the app ends up in the same "two mappings, drifting" state this report is trying to fix. Do this as one deliberate, tested change, not incrementally.
- **Per-row motion** risks reintroducing the exact stutter bug documented in `tasks/lessons.md` ("never swap the image under a symbol effect") if implemented carelessly — SwiftUI `.animation()` on opacity/scale is safe; anything that swaps images or uses `SymbolEffect` needs the same care the menu-bar icon code already took.
- **Cross-session conflict detection** depends on repo/path data that may not currently reach the hook payload in a reliable form — verify data availability before committing to the UI for it, so the feature doesn't ship half-populated.
- **Staying an ambient glancer rather than building a dashboard** is itself a strategic bet, not a neutral default — if AgenticGlow's actual users want an active command center (worth a direct question to any current users, not just this research), the roadmap in §14/§15 would need to reprioritize toward the overview screen over the escalation-tier card.

---

## 17. Expected impact

- The quick wins (§13) remove real bugs (VoiceOver gap, stale Reduce Motion state, drifting color logic) and should ship regardless of any strategic direction decision — they're correctness fixes, not redesign.
- The failure-state addition (§14.1) is the single highest-leverage change: almost every other "does this need my attention" improvement in this report depends on being able to distinguish a broken session from a finished one.
- The escalation-tier card (§7/§5) is the most visible UX improvement a user will notice day-to-day, and it's built entirely from data the app already collects — low new-code cost for a real experience upgrade.

---

## 18. Roadmap summary

| Tier | Items | Depends on |
|---|---|---|
| Quick wins | §13.1-6 | nothing — ship independently |
| Medium effort | §14.1-5 | §14.1 (failure state) should land first; §14.2-4 build on it |
| Long-term | §15.1-3 | §15.3 needs a separate verification pass on hook payload data before any UI work starts |

## 19. Sources

Full citation list from the research pass (Apple HIG, Ware's pre-attentive attribute framework, NN/g, WCAG 2.1, and current product documentation/coverage for Claude Code, Cursor, Warp, Devin, OpenHands, K9s/Lens, SOC dashboard literature) is preserved in this session's research transcript. Ask if you want the full link list extracted into this file.
