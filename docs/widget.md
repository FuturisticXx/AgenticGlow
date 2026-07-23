# AgenticGlow Widget

A native WidgetKit extension (`AgenticGlowWidget`) that shows session and
allowance status on the desktop without opening the app. This document
covers the shared snapshot architecture, the widget UI, and the intentionally
deferred configuration features.

## Status: implemented; runtime data path verified locally

This pass ships:

- A real, tested, versioned snapshot model (`WidgetSnapshot` and friends)
  and a pure builder (`WidgetSnapshotBuilder`) that turns the app's live
  `ResolvedSessions` + allowance state into that snapshot. Both live in
  `AgenticGlowCore` so they're covered by the existing unit test target.
- The WidgetKit extension itself (`Sources/AgenticGlowWidget/`): small,
  medium, and large layouts, all built and previewed against sample data.
- `AppGroupSnapshotSource` and `AppGroupSnapshotWriter`, which read and write
  `WidgetSnapshot.json` through `group.com.twodamax.agenticglow`.
- Live `AppModel` synchronization and `WidgetCenter.reloadAllTimelines()`
  calls when a meaningfully different snapshot is written.
- Matching signed App Group entitlements for the app and widget extension.
  A signed local Release build installed at `/Applications/AgenticGlow.app`
  produced a real snapshot containing Codex and Claude sessions plus both
  allowance records on July 21, 2026.

The final desktop render with current real data is not yet verified. macOS had
zero AgenticGlow widget instances after the stale test widget was removed, so
there was no widget process or desktop surface to inspect. Do not treat the
successful shared snapshot or preview coverage as proof of the final render.

App Intent configuration (filtering by provider/session) and interactive
widget actions beyond opening the app/a session remain out of scope.

## Architecture

```
AppModel (live state, 2s poll)
   -> WidgetSnapshotBuilder.build(...)          [Core, pure, tested]
   -> WidgetSnapshot (Codable)                  [Core]
   -> written atomically to the App Group
      shared container as WidgetSnapshot.json
   -> WidgetCenter.reloadAllTimelines()

AgenticGlowWidget extension (sandboxed, separate process)
   -> AppGroupSnapshotSource.loadSnapshot()      [Core]
      returns .notConfigured / .noSnapshotYet /
              .corrupted / .loaded(WidgetSnapshot)
   -> AgenticGlowTimelineProvider                [Widget target]
   -> AgenticGlowWidgetView (small/medium/large) [Widget target]
```

The widget extension only depends on `AgenticGlowCore`, never on the
`AgenticGlowApp` target. It cannot reuse `AllowancePresentation`,
`StatusPresentation`, or `ProviderColor` directly (AppKit-flavored, app
target only); their formatting conventions are re-expressed as small pure
functions in `WidgetSnapshotFormatting.swift` and two duplicated color
constants in `WidgetColorPalette.swift`.

## Snapshot schema

`WidgetSnapshot` (`Sources/AgenticGlowCore/Widget/WidgetSnapshot.swift`),
versioned via `schemaVersion` (currently `1`):

- `generatedAt`: when the app built this snapshot.
- `sessions`: up to `WidgetSnapshotBuilder.maximumSessions` (8), already in
  the same priority order as the main app (permission > usingTool >
  thinking > failed > completed > disconnected > idle). Each entry carries
  provider, project name, phase, tool category, elapsed seconds, last
  updated time, and a `needsAttention` flag (`.permission` or `.failed`).
- `allowances`: one entry per enabled provider with usage data.
- `providers`: one entry per known provider with an `installed` flag (hook
  integration configured or not).
- `attentionCount`: computed over the full session set, not just the
  capped list, so the small widget's headline number is always accurate
  even when more sessions exist than fit on screen.
- `activeCount`: passed straight through from `ResolvedSessions`.

Only fields already covered by the existing privacy contract
(`docs/privacy.md`) are included. No prompts, no raw provider responses, no
credentials. `projectName` is the only free-text field, and it is already
shown today in the main popover.

Schema changes: bump `WidgetSnapshot.currentSchemaVersion` and keep
decoding permissive (the widget must never crash on an unknown or older
`schemaVersion`; unknown extra fields decode silently, missing new fields
should have safe defaults).

## Refresh behavior and its limits

WidgetKit does not support continuous updates. The MVP timeline provider
(`AgenticGlowTimelineProvider`) requests one more check 15 minutes out as a
fallback, on top of the `WidgetCenter.reloadAllTimelines()` calls the app makes
after meaningful snapshot changes and WidgetKit's own system-managed refresh
budget. Do not expect sub-minute updates; the widget is a glance, not a live
view.

Freshness is evaluated client-side: `WidgetDataFreshness.evaluate` marks a
snapshot stale once it's older than 15 minutes (`staleThreshold`), above
the app's own idle allowance refresh interval (5 minutes) so a normal idle
gap doesn't falsely read as stale.

### Explicit states

- **Fresh** / **Stale**: `.loaded(snapshot)`, freshness evaluated against
  `snapshot.generatedAt`.
- **No data yet**: `.noSnapshotYet` — the container path resolves but no
  snapshot file exists there. This is expected after adding the widget but
  before the correctly signed main app has launched and written its first
  snapshot.
- **Main app not configured**: `.notConfigured` — `containerURL(...)`
  returned `nil`. Reachable in principle (e.g. a stricter sandbox
  environment, or a revoked entitlement after having one), but not the
  state observed live on this Mac.
- **Provider disconnected / not set up**: per-provider `installed: false`
  in the snapshot; shown as a neutral "not set up in AgenticGlow" line in
  the large layout rather than alarming language, since the common case is
  simply "I don't use this provider."
- **Error / unavailable**: `.corrupted` — a snapshot file exists but failed
  to decode.
- **Permission / setup required**: surfaced per-session via
  `needsAttention` (phase `.permission`), promoted above regular sessions.
- **Loading**: WidgetKit's own placeholder/redacted state
  (`TimelineProvider.placeholder(in:)`), shown briefly before any real
  entry loads.

## Widget families

- **Small**: one glance. Priority: attention count, then active session
  count, then lowest individual allowance window remaining (across every
  provider and window kind, not just each provider's current window), then
  a calm "All quiet" state.
- **Medium**: up to 2 sessions (`+ N more` if truncated), an attention
  banner pinned above them when needed, and one status bar for whichever
  individual allowance window (current or weekly, any provider) is lowest.
- **Large**: a per-provider allowance block showing every window the
  provider reports (current, and weekly when the provider has one) using
  the menu-bar-style status bar, plus sessions and provider setup notices.
  Session count adapts to how many allowance windows are showing (see
  below). No app title or last-updated footer: both routinely clipped off
  the bottom of the real fixed-height canvas, confirmed on an installed
  desktop widget, and neither carried information the widget's context
  (the desktop, right next to the app) doesn't already make obvious.
- `.systemExtraLarge` was evaluated and skipped for this pass (iPad
  dashboard-oriented, not clearly worth it for a status companion).

### Allowance windows

`WidgetAllowanceSummary.windows` (`WidgetSnapshot.swift`) is a computed,
non-serialized projection: it always includes the current window, and adds
a second "Weekly" window only when the provider actually reports
`weeklyPercentLeft`. This is why the large widget currently shows exactly
three bars — Codex Weekly, Claude 5h, Claude Weekly — driven entirely by
what the real snapshot contains, not a hardcoded count. If Codex starts
reporting a separate weekly percentage alongside its current window, a
fourth bar appears automatically.

Medium and small pick the single lowest window with
`snapshot.allowances.flatMap(\.windows).min(by: percentLeft)`, so a
provider's weekly percentage can win even when its own (or another
provider's) current window is numerically higher.

The status bar itself (`WidgetAllowanceBar.swift`) is a widget-local port
of the menu bar's `AllowanceBar` (`AllowanceSectionView.swift`, frozen,
reference only): quiet capsule track, provider-colored gradient fill sized
by `WidgetAllowanceWindow.normalizedProgress` (percent clamped to 0...1,
4pt minimum visible width), and a white monospaced percentage pill at the
fill edge. Below the threshold shared with the menu bar
(`AllowanceWarning.thresholdPercentLeft`, `AgenticGlowCore`) a row adds a
red warning triangle and provider-colored caption text; a `nil` percentage
renders as an "Unavailable" line with no bar, never an empty (0%-looking)
one.

Large's displayed-session cap scales down as allowance windows take more
of the fixed, non-scrolling canvas: 4 sessions at 0-2 windows, 3 at exactly
3, 2 at 4 or more (`LargeWidgetView.displayedSessionLimit`). Medium's cap
stays fixed at 2. A `Text("+ N more")` line is intentional and honest
either way, not a bug.

### Typography

Primary widget text now uses explicit point sizes matching Apple's own
weather/stocks widgets rather than `.caption`-family text styles with
`.fontWidth(.condensed)`: session project names and provider headings 14pt
semibold, status/window labels 12-13pt medium, percentage pills 12pt
semibold, reset captions 11pt medium, small's primary metric 28pt medium.
`EmptyStateView` (the pre-add gallery preview) was left untouched, out of
scope for this pass.

### Rendering-mode legibility (Tinted/Monochrome desktop widget styles)

macOS can render any desktop widget in a system "Tinted" or "Monochrome"
style instead of full color, chosen per-widget and derived from the
current wallpaper. This is exposed to SwiftUI as
`@Environment(\.widgetRenderingMode)`
(`.fullColor` / `.accented` / `.vibrant`). Content not marked
`.widgetAccentable()` falls into a fixed "default" tone; content marked
`.widgetAccentable()` picks up the wallpaper-derived accent. Live testing
against an installed desktop widget (not previews — previews always render
`.fullColor` and would never have caught this) found two real problems
only visible in Tinted mode against a pale wallpaper:

1. The allowance bar's percentage pill (`WidgetAllowanceBar.swift`) used a
   custom provider-colored background behind white text. Neither element
   was accentable, so with a pale wallpaper the system's derived accent
   landed close to white for everything, making the percentage
   unreadable and the provider dot/low-state caption colors
   (`AllowanceStrip.swift`) wash out the same way.
2. Even after marking the colored elements `.widgetAccentable()`, a pale
   wallpaper's derived accent could still be too close to white for
   reliable contrast — the system substitution itself, not just missing
   accent markers, was the limiting factor.

Fix: `WidgetAllowanceBar` and `AllowanceStrip` branch on
`widgetRenderingMode`. In `.fullColor` they render exactly as designed
(gradient fill, colored pill, provider-tinted captions). Outside
`.fullColor` they fall back to `Color.primary`/`.foregroundStyle(.primary)`
for the fill and percentage text — semantic styles WidgetKit guarantees
stay legible against any rendering-mode substitution, at the cost of
losing per-provider hue distinction in Tinted/Monochrome mode (an
acceptable, and largely unavoidable, trade-off: the whole point of those
styles is a single-hue treatment). The low-state red warning triangle
still uses its fixed color unconditionally in every mode; a real
remaining limitation if a future desktop test shows it also washing out.

The percentage label's horizontal position is offset a fixed 14pt past the
fill edge rather than centered exactly on it (`labelTrailingOffset` in
`WidgetAllowanceBar`) — centering read as the number floating in the
middle of the bar once it lost its full-color pill background, per direct
feedback from the installed widget.

## Deep links

Scheme: `agenticglow://`. Parsing and construction are pure and tested
(`Sources/AgenticGlowCore/Widget/WidgetDeepLink.swift`); `AppDelegate`
registers a `kAEGetURL` Apple Event handler and routes through the
existing `AppModel.activate(_:)` / popover-show methods, no new activation
logic.

- `agenticglow://open` — bring the app popover forward. Used as the
  default `.widgetURL` for the whole widget.
- `agenticglow://session?provider=<claude|codex>&id=<sessionID>` — used per
  row in medium/large; activates that session's source app window (if
  still resolvable) and shows the popover.

## Privacy

No new network requests. No credentials, cookies, or raw provider
responses in the snapshot. The App Group container is shared only by
AgenticGlow and its own widget extension, using the same protection model as
other sandboxed shared containers. The main app atomically overwrites one
`WidgetSnapshot.json` file and does not retain widget history. See
`docs/privacy.md` for the complete contract.

## Supported families and macOS versions

Small, medium, large. macOS 14.0+ (matches the app's deployment target).
Uses `.containerBackground(.background, for: .widget)` on every root view
(required since macOS 14 WidgetKit; omitting it renders a blank/black
widget). No macOS 26-only symbols.

## Testing locally

1. `xcodegen generate`
2. `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -skip-testing:AgenticGlowUITests` — covers every pure Core widget file (snapshot codable/schema, builder, formatting, freshness, deep link, snapshot-loading safety). On Xcode versions that still prepare the skipped UI runner, run the built non-UI XCTest bundles directly and record that limitation instead of treating a runner timeout as a product-test failure.
3. Xcode canvas: open any file under `Sources/AgenticGlowWidget/Views/` and use the `#Preview` blocks — every family has previews across the major states (busy, attention, failed, low allowance, provider not set up, stale, no data yet, not configured, error).
4. Real install: build and run AgenticGlow once with the Apple Development identity, then right-click the desktop, choose **Edit Widgets**, search for **AgenticGlow**, and add a widget. The app writes `WidgetSnapshot.json` into `~/Library/Group Containers/group.com.twodamax.agenticglow/` and asks WidgetKit to reload after meaningful changes.
5. Before trusting the result, run `pluginkit -m -A -D -v -i com.twodamax.agenticglow.widget` and confirm exactly one registration points inside `/Applications/AgenticGlow.app`. A DerivedData or `/tmp` path means macOS may launch a stale extension with different entitlements.

## Live-data verification

`AppModel` calls
`WidgetSnapshotBuilder.build(...)` after `refresh()` and
`syncAllowanceStates()`, writes atomically via `AppGroupSnapshotWriter` to
`WidgetSnapshot.json` in the shared container, and calls
`WidgetCenter.shared.reloadAllTimelines()` only when
`WidgetSnapshotBuilder.isMeaningfullyDifferent` says something worth
showing actually changed (elapsed-seconds ticking alone does not trigger a
reload, to stay well under WidgetKit's reload budget). `installedProviders`
comes from the existing `ClaudeIntegrationManager`/`CodexIntegrationManager`
`.status().installed`. All of this is covered by unit tests
(`AppGroupSnapshotWriterTests`, the `isMeaningfullyDifferent` cases in
`WidgetSnapshotBuilderTests`).

The installed local Release build is signed with matching App Group
entitlements for `com.twodamax.agenticglow` and
`com.twodamax.agenticglow.widget`. The signed extension profile includes
`group.com.twodamax.agenticglow`, deep signature validation passes, and
launching the app writes a decodable live snapshot to the shared container.

On July 21, 2026, the installed app had one widget registration pointing to
`/Applications/AgenticGlow.app`. Its fresh snapshot contained seven Codex
sessions, one Claude session, and allowance data for both providers. The
system widget metadata contained zero installed AgenticGlow desktop instances,
so the current-data desktop render remains explicitly unverified.

### Allowance-window parity pass (2026-07-22)

Added `WidgetAllowanceWindow`/`WidgetAllowanceSummary.windows`
(`WidgetAllowanceWindowTests.swift`, 7 cases, TDD red-then-green), ported
the menu bar's status bar into the widget target (`WidgetAllowanceBar.swift`),
rewrote `AllowanceStrip`/added `AllowanceWindowRow` to render one bar per
window instead of only the current window, fixed medium/small to select
the lowest individual window instead of the lowest provider's current
window, raised primary typography, and made large's session cap adapt to
allowance-window count. Full non-UI suite: 263 Core + 6 Event + 143 App,
0 failures (up from 262/6/143; +7 for the new window tests, net widget
view line count changes only). `Scripts/verify-privacy.sh` exit 0.

Cleaned up a second stale `pluginkit` registration found at
`/private/tmp/agenticglow-publish-signed/...` (a leftover Debug build from
publish tooling) and a transient one that appeared at
`build/DerivedData/.../AgenticGlow.app` after this session's own local
Debug build/install; exactly one registration remains, pointing to
`/Applications/AgenticGlow.app`. Confirmed matching `group.com.twodamax.agenticglow`
entitlement on both the app and widget, and a universal (`x86_64 arm64`)
widget binary.

Could not read the live `WidgetSnapshot.json` directly from a shell in this
session: macOS App Sandbox group-container files are only readable by
processes carrying the matching `group.com.twodamax.agenticglow`
entitlement, and neither `cat`, Python, nor `osascript` running outside the
app have it (`Operation not permitted` even with root-equivalent POSIX
permissions on the file). This is expected sandbox behavior, not a bug.
Real-data freshness and correctness were confirmed instead by directly
inspecting the installed desktop widget itself (see below), which is
stronger evidence than a raw file read anyway since it proves the full
pipeline end to end.

### Real desktop widget verification (2026-07-22)

John added the large AgenticGlow widget to a live desktop and confirmed,
across several iterations against his real wallpaper and widget style
settings:

- Exactly three allowance bars render for the real live data: Codex
  Weekly, Claude 5h, Claude Weekly, each with a visibly different fill and
  a readable percentage (16%, 70%, 50% at the time of the final check).
- Reset captions read correctly ("Weekly resets in 144h 16m left", "5h
  resets in 3h 24m left", etc.).
- Session rows show live Codex/Claude session data with correct project
  names, phase, and provider.
- The widget's desktop compositor surface could not be captured by this
  session's screenshot tooling (same restriction that blocks Notification
  Center — system UI layers outside the normal app windowing model); every
  round of this verification relied on John's direct screenshots rather
  than automated capture, consistent with `docs/tasks/lessons.md`'s rule
  to never claim visual completion from previews alone.
- The widget extension is a long-lived background process that does not
  restart just because the containing app is quit/relaunched or the
  `.appex` bundle on disk is replaced; each local rebuild in this session
  required explicitly killing the running `AgenticGlowWidget` process
  (`pkill -f .../AgenticGlowWidget.appex` or a plain `kill <pid>`) so
  macOS would respawn it from the new binary before a code change was
  actually visible on the desktop.
- Each local Debug rebuild/install also registered a second, transient
  `pluginkit` entry pointing at `build/DerivedData/.../AgenticGlow.app`
  (Xcode's own `RegisterWithLaunchServices` build phase), removed after
  each install so exactly one registration remains, pointing at
  `/Applications/AgenticGlow.app`.

Ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) cannot sign App Group entitlements,
so widget runtime checks must use the Apple Development identity. The release
builder now signs the helper, then the widget with
`Config/AgenticGlowWidget.entitlements`, then the containing app.
`Scripts/verify-release.sh` requires the embedded widget, both architecture
slices, a valid widget signature, and the shared App Group entitlement on both
targets. A notarized release containing this feature has not yet been produced.
App Intent filtering and additional interactive actions remain follow-up work.
