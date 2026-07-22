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
  count, then lowest allowance remaining, then a calm "All quiet" state.
- **Medium**: up to 2 sessions (`+ N more` if truncated), an attention
  banner pinned above them when needed, and one allowance strip for
  whichever provider is lowest.
- **Large**: up to 4 sessions (`+ N more` if truncated), a per-provider
  allowance block, provider setup notices, and a last-updated/staleness
  footer.
- `.systemExtraLarge` was evaluated and skipped for this pass (iPad
  dashboard-oriented, not clearly worth it for a status companion).

Session counts (2 for medium, 4 for large, independent of
`WidgetSnapshotBuilder.maximumSessions` = 8) are a conservative estimate
against each family's fixed canvas: an attention banner, several rows, an
allowance block, and a footer sharing the same non-scrolling space add up
fast. Not confirmed against a live-measured render (no way to screenshot
Xcode's canvas in this environment, see "Testing locally" below) — if a
busy real-data state still clips on your Mac, lower these further; a
`Text("+ N more")` line is intentional and honest either way, not a bug.

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

Ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) cannot sign App Group entitlements,
so widget runtime checks must use the Apple Development identity. The release
builder now signs the helper, then the widget with
`Config/AgenticGlowWidget.entitlements`, then the containing app.
`Scripts/verify-release.sh` requires the embedded widget, both architecture
slices, a valid widget signature, and the shared App Group entitlement on both
targets. A notarized release containing this feature has not yet been produced.
App Intent filtering and additional interactive actions remain follow-up work.
