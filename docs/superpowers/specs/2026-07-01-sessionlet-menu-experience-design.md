# Sessionlet Menu Experience Design

Date: July 1, 2026

Status: Approved design, pending review of this written specification

## Summary

Sessionlet is a native macOS menu-bar utility for monitoring local Codex and Claude sessions. This design rebuilds the menu experience around one reading order:

1. Does an agent need attention?
2. What is each agent doing, and in which project?
3. How much subscription allowance remains, and when does it reset?

The popover leads with live activity and keeps subscription allowance visible but quieter. Provider usage access remains explicitly opt-in and uses direct requests from the Mac to OpenAI or Anthropic with existing locally stored credentials. Sessionlet operates no server and collects no analytics or telemetry.

## Goals

- Make permission needs obvious in one glance.
- Show provider, project, activity, and elapsed time without interpretation.
- Show Codex and Claude subscription allowance in a comparable format.
- Preserve provider-native Claude usage language without forcing mental arithmetic.
- Feel calm, native, and visually coherent in Light and Dark appearances.
- Add near-real-time allowance updates without noticeable CPU, memory, battery, or network impact.
- Preserve Sessionlet's strict privacy boundary.

## Non-Goals

- Approving or denying provider permissions from Sessionlet.
- Showing prompts, responses, commands, tool arguments, file contents, or transcripts.
- Tracking token counts, cost, historical trends, or daily usage charts.
- Operating a Sessionlet account, backend, proxy, or telemetry service.
- Replacing provider billing or account-management interfaces.
- Guaranteeing freshness beyond what provider usage systems report.
- Changing integration installation, session-state normalization, or source-app activation except where needed to support the approved menu experience.

## Design References

The design synthesizes these patterns without copying any one product:

- Apple Human Interface Guidelines: familiar macOS menu behavior, native controls, semantic color, and adaptive appearance.
- Apple Liquid Glass guidance: system-provided material first, custom glass only where needed, and automatic adaptation to surrounding content.
- OpenAI Codex usage guidance: plan allowance varies with task size and is surfaced through provider usage information.
- Anthropic usage guidance: session and weekly limits have separate reset schedules.
- Native monitoring utilities such as iStat Menus: glanceable summary first, details on demand.
- Current allowance utilities such as Headroom and MeterBar: compact window labels, percentages, progress bars, and reset times.

## Information Hierarchy

### 1. Attention

If one or more agents need permission, the popover begins with an amber summary such as `1 agent needs you`.

Permission rows appear before all other session rows. Each row shows:

- Project name.
- Provider.
- `Permission needed`.
- A disclosure cue indicating that selecting the row returns to the source application.

Amber communicates attention without implying a failure. Red is reserved for destructive or unrecoverable conditions and is not used for normal permission requests.

### 2. Active work

The normal popover header summarizes current work, for example `2 agents working`.

Each session row shows:

- Project name as the primary label.
- Provider and current activity as the secondary label.
- Elapsed turn time at the trailing edge when applicable.
- A small semantic state marker.

Rows remain grouped by urgency, not by provider. Permission rows come first, working rows follow, then completed, idle, and disconnected rows. Provider identity remains visible within each row.

Selecting a row activates the best-known source application using the existing activation behavior.

### 3. Subscription allowance

Allowance appears beneath session activity under a quiet `ALLOWANCE` label.

Codex shows:

- Five-hour percentage left.
- Time until the five-hour reset.
- Weekly percentage left.
- Weekly reset day and time.

Claude shows:

- Current-session percentage left as the primary value.
- Current-session percentage used as secondary context.
- Time until the current-session reset when available.
- Weekly percentage left as the primary weekly value.
- Weekly percentage used as secondary context when space permits.
- Weekly reset day and time when available.

The compact language is:

- `74% left`
- `39% left · 61% used`
- `5h · 2h 18m`
- `Week 82% · Mon 9 PM`

Percentages use monospaced digits. Progress bars visualize the amount left for both providers so the same direction always has the same meaning.

## Popover Layout

The popover uses one vertical reading path:

1. Attention or working summary.
2. Session rows.
3. Allowance.
4. One trailing gear control.

The gear menu contains:

- `Refresh Usage` when usage access is enabled.
- Usage freshness or provider connection details.
- `Integrations…`.
- `Settings…`.
- A separator.
- `Quit Sessionlet`.

The existing persistent `Integrations`, `Settings`, and `Quit` buttons are removed from the popover footer. This keeps the primary surface focused on status and allowance.

## Menu-Bar Icon

Sessionlet keeps the existing `circle.hexagongrid` SF Symbol as its menu-bar identity.

- Idle: static `circle.hexagongrid`.
- Thinking or tool use: the same symbol rotates slowly.
- Permission: `exclamationmark.circle.fill` with semantic amber.
- Completed: `checkmark.circle.fill` with semantic green.
- Disconnected: `bolt.slash.circle` with secondary-label coloring.

The working animation uses the native AppKit symbol-effect system rather than a SwiftUI pulse or a high-frequency timer. The effect starts once when the dominant state enters thinking or tool use and stops once when that state ends.

No custom square, circle, capsule, or background sits behind the menu-bar symbol. macOS supplies its normal hover and pressed treatments.

When Reduce Motion is enabled, the working symbol remains static.

## Appearance and Material

Sessionlet follows the Mac's current Light, Dark, or Auto appearance. It does not add a separate in-app appearance selector in this scope.

On macOS 26 and later:

- Use system Liquid Glass behavior and standard controls where available.
- Use custom glass only for app-specific surfaces that standard components do not cover.
- Keep semantic color limited to state markers, allowance bars, and attention treatment.

On macOS 14 and 15:

- Use native adaptive material and standard SwiftUI/AppKit controls.
- Preserve the same hierarchy, spacing, contrast, and interaction model.
- Do not imitate Liquid Glass with expensive custom blur stacks or animation.

The design must remain legible over varied desktop backgrounds in both appearances.

## Explicit Usage Opt-In

Usage requests are off by default.

Before consent, the allowance section shows:

- `Usage access is off`.
- `No provider requests are being made.`.
- An `Enable…` action.

The consent sheet explains that Sessionlet can request subscription allowance directly from each provider using credentials already stored on the Mac.

OpenAI Codex and Anthropic Claude have separate toggles. Either provider can be enabled or disabled independently.

The sheet states:

- Requests go only to the selected provider.
- Sessionlet has no server.
- Sessionlet collects no analytics or telemetry.
- Sessionlet does not copy provider credentials into its own persistent store.
- Access can be disabled at any time.

The primary action is `Enable Usage`; the alternative is `Not Now`.

Disabling a provider stops its future requests and removes its cached allowance display.

## Credential Boundary

Provider adapters may read only the existing local credential material required to authenticate the direct usage request. They must not:

- Log credentials or authorization headers.
- Upload credentials anywhere except the selected provider's authenticated endpoint.
- Copy credentials into Sessionlet preferences, diagnostics, session files, or caches.
- Include credential-derived data in analytics, because Sessionlet has no analytics.

If credentials are absent, expired, unsupported, or inaccessible, Sessionlet reports that usage access is unavailable and points the user to the provider's normal sign-in flow. Sessionlet does not create, refresh, or replace provider credentials outside provider-supported behavior.

## Refresh Strategy

Allowance refresh uses an event-driven strategy with a bounded polling fallback.

- Refresh after a completed agent turn, debounced by three to five seconds.
- While an agent is working, refresh at most once per 60 seconds.
- When the popover opens, refresh if the cached data is older than 15 seconds.
- When all agents are idle, refresh at most once every five minutes.
- Suspend background refresh while the Mac is asleep or the network is unavailable.
- Permit only one in-flight request per provider.
- Coalesce duplicate refresh triggers.
- Apply exponential backoff with jitter after provider errors or rate limiting.
- Respect provider retry guidance when a response supplies it.

This strategy aims for updates shortly after provider usage is recorded without constant polling. The interface does not claim exact real-time data because provider reporting may lag.

## Freshness, Loading, and Errors

### First load

After opt-in and before the first successful response, show a compact loading state in the allowance section. Agent activity remains fully usable.

### Successful data

Show percentages and resets without an `Updated` label while the data is fresh.

### Stale cached data

Keep the last valid values visible and add a quiet freshness label such as `Updated 8m ago`.

### No valid cached data

Show `Unavailable` for the affected provider with a short reason accessible through the gear menu.

### Partial failure

Codex and Claude fail independently. A failure for one provider does not hide valid data for the other provider and never replaces agent status.

### Rate limiting

Keep cached values, show freshness, follow backoff rules, and avoid repeated warning surfaces.

## Component Responsibilities

### Session summary

Computes the short header from resolved session state and attention count.

### Session row

Displays project, provider, activity, elapsed time, and semantic state. Activates the source application when selected.

### Allowance section

Displays opt-in, loading, fresh, stale, partial, and unavailable states. It does not perform network requests directly.

### Provider allowance row

Formats one provider's current and weekly values using the shared left-first visual direction.

### Usage consent sheet

Controls provider-specific opt-in and explains the network and credential boundary.

### Gear menu

Holds secondary actions and usage diagnostics without competing with live status.

### Provider usage adapters

Obtain provider-specific usage data, normalize it into a shared model, and expose freshness and reset information. Provider-specific authentication and response details remain isolated from UI code.

### Usage refresh coordinator

Coalesces event triggers, enforces cadence and one-request-per-provider limits, manages backoff, and updates the cache.

## Normalized Allowance Model

The UI consumes a provider-neutral model with optional fields because providers may not return identical information:

- Provider.
- Current-window label.
- Current-window percentage used.
- Current-window percentage left.
- Current-window reset date.
- Weekly percentage used.
- Weekly percentage left.
- Weekly reset date.
- Fetch date.
- Freshness state.
- Availability state.

Percentages are clamped to the display range from zero through 100. Missing values remain absent rather than being inferred from unrelated data. `left` may be calculated as `100 - used` only when the provider defines the returned value as a percentage of the same allowance window.

## Privacy and Local Storage

Sessionlet stores only the latest normalized allowance response needed for the current display and its fetch timestamp.

- No usage history.
- No token history.
- No cost history.
- No provider response bodies after normalization.
- No credentials in the allowance cache.
- No analytics or telemetry.

The cache follows existing user-only local storage protections. Disabling a provider removes its cached allowance immediately.

## Performance Budget

The feature must not produce a user-noticeable performance dip.

- Idle CPU remains near zero between scheduled work.
- Working-state average CPU attributable to Sessionlet remains below 0.5 percent during representative sampling.
- No high-frequency UI timer drives allowance or menu-bar animation.
- Provider responses are normalized and discarded promptly.
- Only the latest normalized provider values remain in memory and local cache.
- At most one request per provider is active.
- Network work never runs on the main thread.
- Unchanged menu presentations remain cached.
- Reduced Motion disables the working rotation.

These are release gates, not assumptions. Profiling must verify them on the Release build.

## Accessibility

- VoiceOver reads project, provider, activity, and source surface for each session.
- Permission rows identify that selecting them returns to the source application.
- Percentages and reset times have complete spoken labels rather than abbreviated visual strings.
- Color is never the only indication of attention, working, completion, or error state.
- Keyboard navigation reaches every session row, `Enable…`, and the gear menu.
- Progress bars expose provider, window, percentage left, and reset information.
- The interface respects Reduce Motion, Increase Contrast, and system Light/Dark appearance.
- Compact controls retain standard macOS pointer targets and focus treatment.

## Verification

### Design and visual verification

- Compare Light and Dark appearances over light, dark, and high-detail desktop backgrounds.
- Verify the macOS 26 Liquid Glass treatment and the macOS 14–15 material fallback.
- Verify the popover at zero, one, several, and overflow session counts.
- Verify permission, working, completed, idle, disconnected, loading, stale, unavailable, and partial-provider states.
- Verify the bare menu-bar icon at actual menu-bar scale.

### Functional verification

- Usage remains off until explicit provider opt-in.
- Each provider can be enabled and disabled independently.
- Disabling a provider stops requests and removes its cached allowance.
- Turn completion, active fallback, popover opening, and idle cadence trigger refresh according to policy.
- Duplicate triggers coalesce and only one request per provider runs at once.
- Errors and rate limits back off without disrupting live session state.
- Percentage direction and reset formatting match the normalized model.

### Privacy verification

- No request occurs before opt-in.
- Requests go directly to the selected provider.
- Credentials and authorization headers never appear in logs, diagnostics, preferences, session files, or caches.
- No raw provider response remains after normalization.
- No analytics or telemetry endpoint exists.

### Performance verification

- Repeat the prior beachball sampling on a Release build.
- Profile CPU, memory, Energy Impact, main-thread responsiveness, and animation behavior while idle and while agents work.
- Test with both providers enabled, one provider enabled, provider errors, rate limiting, sleep/wake, and network loss.
- Confirm that the native symbol effect stops when work ends and does not run under Reduce Motion.

## Implementation Gate

This document defines the approved product and interaction design. It does not authorize release, tagging, pushing, publication, credential changes, or provider access before the implementation is reviewed and tested.

Implementation planning begins only after John reviews and approves this written specification.
