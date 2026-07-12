# Current Work

- Monitor public v0.4.7 behavior and incoming reports.
- Submit the maintained Cask to `homebrew/homebrew-cask` when AgenticGlow meets Homebrew's published notability threshold.
- Directly confirm the repaired Codex session row in the AgenticGlow popover during a live Codex turn; resolver-level evidence already passes.

The sections below are completed historical plans retained for implementation context.

# Adaptive menu bar icon colors (2026-07-09)

**Status:** Complete and released in v0.4.0. This section is retained as historical implementation evidence.

**Goal:** The working icon's provider colors automatically deepen on light menu bars and brighten on dark ones, riding macOS's own per-wallpaper bar appearance. No border, no screen sampling, no new permissions.

**Mechanism:** macOS flips each menu bar between light and dark appearance based on the wallpaper behind it (how template icons stay legible). The status item button exposes this as effectiveAppearance; KVO-observe it and swap palettes.

**Known limits (John accepted):** two-mode adaptation, not continuous color matching; one appearance value per status item, so it follows the main display when wallpapers differ.

## Tasks

### Task 1: Two palettes in ProviderColor
- Menu bar palette pairs: dark-bar (bright: current blue 0.25/0.55/1.00, coral 0.85/0.47/0.34) and light-bar (deep: orange 0.82/0.37/0.22, blue ~0.10/0.42/0.88). Popover rows and pills keep the single existing palette.
- bothBlend becomes the midpoint of whichever pair is active.
- [x] Update ProviderColorTests to lock both palettes and midpoints -> verified: 6 ProviderColorTests green (both palettes, midpoints, light-darker-than-dark invariant)

### Task 2: Presentation exposes providers, controller picks colors
- StatusPresentation.activeTints [NSColor] becomes activeProviders [AgentProvider]; StatusItemController resolves colors per appearance at render time.
- [x] Update StatusPresentationTests accordingly -> verified: activeProviders replaces activeTints, 53 app tests green

### Task 3: Appearance observation
- KVO on item.button.effectiveAppearance (aqua vs darkAqua bestMatch); on change invalidate lastPresentation and re-render, motion task picks up new palette next frame without restarting (phase preserved).
- [x] Build passes -> NOTE: KVO observation replaced with per-frame resolution in the motion task; effectiveAppearance KVO fires for our own renders (storm measured at ~325 events/s), so the frame task reads the verdict each frame instead

### Task 4: Verify end to end
- [x] Full unit suite passes; UI suite passes -> verified: 157 core + 53 app + 6 UI, zero failures
- [x] Live verification (method changed: system Light/Dark toggle does not drive bar appearance on macOS 27; wallpaper does) -> verified: white wallpaper on main display gives light verdict and deep palette (bluest pixel rgb(43,119,209), distance 26 to deep vs 55 to bright); pink wallpaper gives dark verdict. Sweep 9.99s vs 10.0 target; rotation autocorrelation peak +0.95 at 2.0s lag (12s/rev).
- Caveat (system behavior, affects all menu bar apps): macOS lags flipping bar appearance after a wallpaper change (Apple's own template icons rendered black on a near-black bar during the lag). Our icon follows the same system verdict as every other icon.
- Caveat: macOS dims menu bar content on inactive displays; that dimming, not the palette, is what washes the icon out on secondary displays.

---

# v0.3.0: Notifications, Low-Allowance Badge, Incident Status, Reset Celebration (2026-07-08)

**Status:** Implemented and released as part of v0.4.0. The unchecked verification items below are preserved as the original plan and are not current work.

**Goal:** AgenticGlow proactively tells John when an agent needs him or usage runs low, hints low allowance on the menu bar icon, surfaces provider incidents in the popover behind an explicit opt-in, and celebrates the weekly usage reset.

**Architecture:** Pure decision logic (transition detection, thresholds, dedupe, status normalization) lives in AgenticGlowCore with unit tests. The app layer adds a thin UNUserNotificationCenter wrapper, three preference toggles, a status-item badge dot, and a popover incident line. All wiring flows through AppModel, matching the existing allowance pattern.

## Global constraints

- macOS 14.0 deployment target; CI builds with Xcode 16.4. Gate anything newer than macOS 14 with #available; compile-guard anything newer than the CI SDK. No macOS 26 symbols.
- No em dashes in any user-facing string.
- Scripts use only tools preinstalled on GitHub runners (grep, not rg).
- Scripts/verify-privacy.sh must pass; docs/privacy.md must enumerate every network endpoint.
- Surgical changes only; match existing style.
- No push, no release, no version bump. Commits stay local for John's review.
- Status endpoints (verified live 2026-07-08, both Statuspage v2 {"status":{"indicator":...,"description":...}}):
  - Claude: https://status.claude.com/api/v2/status.json
  - Codex/OpenAI: https://status.openai.com/api/v2/status.json

## Design decisions

- Low-allowance threshold: under 10 percent left, current or weekly window, fresh or stale. One Core constant shared by badge and notification.
- Quota notifications dedupe in memory per (provider, window label, resetAt) per app run. Relaunch may re-fire once; acceptable.
- Permission notifications fire only on transition into the permission phase (previous phase map already exists in AppModel.refresh()).
- Incident checks run only when the popover opens, 10 minute TTL, GET only, nothing persisted, no cookies or identifiers. Opt-in toggle, off by default.
- Celebration: menu bar icon tints green and bounces about 4 seconds when a weekly window rolls over. Tint-only under Reduce Motion or macOS 14.
- Allowance copy becomes "No usage requests are being made" so it stays honest when status checks are on; verify-privacy.sh updated to match.

## Tasks

### Task 1: Core signal logic
- Create Sources/AgenticGlowCore/Allowance/AllowanceWarning.swift: `AllowanceWarning.thresholdPercentLeft = 10`; `struct Window { label, percentLeft, resetAt }`; `lowWindows(in: ProviderAllowance) -> [Window]`.
- Create Sources/AgenticGlowCore/Allowance/WeeklyResetDetector.swift: `didReset(previous: ProviderAllowance?, current: ProviderAllowance, now: Date) -> Bool` (both weeklyResetAt non-nil, current later than previous, previous not in the future).
- Create Sources/AgenticGlowCore/Notifications/NotificationPolicy.swift: `newlyAwaitingPermission(previousPhases: [String: <session phase type>], sessions: [SessionSnapshot]) -> [SessionSnapshot]`; `struct QuotaAlertTracker { mutating newAlerts(provider:allowance:) -> [AllowanceWarning.Window] }` keyed by provider|label|resetAt.
- Tests first in Tests/AgenticGlowCoreTests/: AllowanceWarningTests (95 used fires, 50 does not, both windows, nil percents), WeeklyResetDetectorTests (rollover true; same resetAt, nil previous, previous-in-future all false), NotificationPolicyTests (idle-to-permission fires, steady permission does not, unseen permission session fires; tracker dedupes per window, refires on new resetAt).
- [ ] Failing tests, implement, pass, commit "feat: core signal logic for notifications, badge, and reset detection"

### Task 2: Core provider status
- Create Sources/AgenticGlowCore/Status/ProviderServiceStatus.swift (.operational / .incident(String)), StatusPageClient.swift (ProviderStatusRequesting protocol; URLSession client, 15s timeout; StatusPageNormalizer: indicator "none" is operational, anything else incident(description, fallback "Service incident")), ProviderStatusMonitor.swift (actor; setEnabled, refreshIfStale with injected TTL 600 and now; status(for:) -> ProviderServiceStatus?; fetch failure yields nil, never an error surface).
- Tests first: StatusPageNormalizerTests (none/minor/critical/garbage), ProviderStatusMonitorTests (disabled: no fetch; TTL respected via counting fake; failure yields nil then recovers).
- [ ] Failing tests, implement, pass, commit "feat: provider status page monitoring in core"

### Task 3: Preferences and notification service
- PreferencesStore: add notifyPermission (default true), notifyQuotaLow (default true), serviceStatusEnabled (default false); default-true keys read via object(forKey:) as? Bool ?? true.
- Create Sources/AgenticGlowApp/Services/AgentNotificationService.swift: protocol AgentNotifying { sessionsNeedPermission([SessionSnapshot]); allowanceUpdated(provider:allowance:) }; protocol UserNotificationScheduling (requestAuthorization, isAuthorized, add(id:title:body:userInfo:), clickHandler); AgentNotificationService reads toggles via closures, applies QuotaAlertTracker, requests authorization at startup when either notify toggle is on (never lazily, so the first alert is not lost to the permission prompt), click handler activates userInfo["sourceBundleID"]. Real UserNotificationCenterClient: UNUserNotificationCenterDelegate didReceive routes to clickHandler on MainActor; willPresent shows .banner.
- Copy: "<Project> needs you" / "<Provider> is waiting for permission."; "<Provider> usage running low" / "5-hour window: N% left." or "Weekly window: N% left."
- Tests first: AgentNotificationServiceTests with fake scheduler (toggles off suppress; dedupe; click activates bundle ID); PreferencesStoreTests extended (defaults true/true/false, persistence).
- [ ] Failing tests, implement, pass, commit "feat: notification service and new preference toggles"

### Task 4: AppModel wiring
- AppModel init gains notifier: (any AgentNotifying)? and statusMonitor: ProviderStatusMonitor?; refresh() reports newly-permission sessions; syncAllowanceStates() reports available allowances, runs WeeklyResetDetector against previous, increments private(set) weeklyResetCount; hasLowAllowance computed; serviceStatuses dict, serviceStatus(for:), setServiceStatusEnabled, refreshServiceStatus().
- AppDelegate builds the service and monitor (skipped in UI-test fixture mode except signals fixture), applies serviceStatusEnabled at launch. StatusItemController.togglePopover also refreshes service status.
- Tests first: AppModelTests with fake notifier (permission transition reported exactly once; allowanceUpdated on fresh state; weeklyResetCount increments; hasLowAllowance at 92 used).
- [ ] Failing tests, implement, pass, commit "feat: wire notifications, status, and reset detection through AppModel"

### Task 5: Menu bar badge and celebration
- StatusPresentation init gains lowAllowance: Bool; new showsAllowanceBadge; accessibilityLabel appends ", usage low".
- StatusItemController: 6pt orange dot view at symbolView top-trailing, hidden unless badge; celebration on weeklyResetCount change (green tint, bounce under #available(macOS 15) unless reduceMotion, restore after 4s via cleared lastPresentation + update()).
- Tests first: StatusPresentationTests extended (badge flag, accessibility, coexists with permission phase).
- [ ] Failing tests, implement, pass, commit "feat: low-allowance badge and weekly reset celebration on the menu bar icon"

### Task 6: Popover incident line, Settings, fixtures
- SessionListView: incident Label per provider under summary (caption, orange, exclamationmark.triangle.fill), rendered only when monitor enabled.
- AllowanceSectionView copy: "No usage requests are being made." Update the matching grep line in Scripts/verify-privacy.sh in this same commit so the privacy gate passes at every commit boundary.
- SettingsView: toggles for permission notifications, quota notifications (with caption when notifications are denied in System Settings), provider incidents ("Checks the public Anthropic and OpenAI status pages when you open AgenticGlow. Off by default. No account data is sent.").
- Fixtures: "signals" fixture (permission + working sessions, fixture allowance adapter codex 92 used current resets +2h and weekly 95 used resets +3d, fixture status requester with canned claude incident, defaults codexUsageEnabled and serviceStatusEnabled true); --ui-test-celebrate bumps weeklyResetCount 3s after launch.
- [ ] Implement, build, commit "feat: incident line, notification and status settings, signals fixture"

### Task 7: Privacy contract and docs
- docs/privacy.md: "Provider service status (optional)" section listing both endpoints, off by default, GET only, in-memory only.
- README.md: privacy paragraph mentions optional status checks; notifications mentioned in features.
- Scripts/verify-privacy.sh: updated allowance copy check; require both status hosts in privacy.md and StatusPageClient.swift; forbid Cookie/credential/authorization in Sources/AgenticGlowCore/Status.
- [ ] Implement, run Scripts/verify-privacy.sh (exit 0), commit "docs: privacy contract covers status checks and notifications"

### Task 8: Full verification (gate for done)
- [ ] xcodegen generate; full unit test suite passes (154 existing + new).
- [ ] Scripts/verify-privacy.sh exits 0.
- [ ] Signed local build; launch with --ui-test-fixture signals --ui-test-open-popover; screenshots prove: orange menu bar badge, popover incident line, low allowance bars.
- [ ] Launch with --ui-test-celebrate; frames at 0s/3s/6s prove green pulse appears and restores.
- [ ] Live permission notification banner screenshot (grant authorization once if prompted).
- [ ] Update gotdone.md; final commit. No push, no release.

---

# Release 0.2.0 with Dark Mode fix (2026-07-05)

**Status:** Complete and released.

John asked to cut the release build containing the Dark Mode popover fix. Since
v0.1.1, main also holds the popover aura, allowance bar redesign, elapsed-seconds
display, refreshed icon, and the Codex bundled-binary allowance fix; that set was
already staged privately as 0.2.0, so this release is 0.2.0.

- [x] Signed universal release build via Scripts/build-release.sh 0.2.0 -> verified: gates passed, codesign strict passed, lipo shows x86_64 arm64
- [x] DMG: create, sign, notarize, staple via Scripts/create-dmg.sh 0.2.0 -> verified: notarization Accepted, staple validated, spctl accepts app and DMG as Notarized Developer ID; DMG SHA-256 9b990455fa7155d13bb4df61137e0fd6cf614e62fe08cd6547b96b901d7ed512
- [x] Installed to /Applications replacing v0.1.1, relaunched -> verified: Info.plist reads 0.2.0, dark popover screenshot from installed app shows scrim + light-palette aura
- [x] John confirmed publication: GitHub release v0.2.0 published from tag at `09dabd6`, downloaded asset checksum/staple/Gatekeeper verified, cask bumped on main (`3b2575f`) and tap updated (`5c21667`)

# Fix: Dark Mode popover too light (2026-07-05)

**Status:** Complete and released in v0.2.0.

Bug report from John: "Dark Mode is too light." Reproduced on macOS 27 in Dark Mode:
the popover glass is nearly transparent, desktop content bleeds through, and the
popover reads light gray instead of dark.

Root cause: on macOS 26+ `SessionListView` uses `Color.clear` as the background,
relying only on the system Liquid Glass popover material. No dark tint exists for
Dark Mode.

Plan (bug fix, autonomous path):

- [x] Reproduce with screenshot of live popover in Dark Mode
- [x] Add a Dark Mode scrim layer behind the popover content in SessionListView
- [x] Build three scrim strengths (A: 0.30, B: 0.45, C: 0.60), screenshot each on the real popover -> verified: side-by-side captures, signed test builds with John's Developer ID so keychain access stayed silent
- [x] Present labeled variants A/B/C to John, with recommendation B
- [x] John picked B (0.45) and clarified "too light" meant the aura border glow: he wants dark mode's aura to match light mode
- [x] Unify PopoverAura: light palette, light opacities, no blend mode, drop unused colorScheme -> verified: rebuilt app screenshot shows saturated azure/gold edges over the dark scrim
- [x] Run /code-review (8 finders + 2 verifiers) -> 2 confirmed findings: pre-macOS-26 dark mode has no scrim (reported, intentionally out of scope, cannot visually verify on this machine); magic numbers -> fixed with named constants
- [x] Tests 154/154 pass, privacy gate passes, committed locally (push pending John's OK)

# Feature: Provider color language for icon and session list (2026-07-08)

**Status:** Complete and released in v0.4.0.

**Goal:** Make the app show which agent is working. One color language, Claude = orange `#D97857`, Codex = azure `#408CFF`, used on the menu bar icon, the session row icons, and the allowance pills (already). The menu bar icon is solid orange when only Claude works, solid blue when only Codex works, and cross-fades blue <-> orange (~3s each way) when both work. The popover summary names the active agents.

**Design approved by John.** Preview shown as an inline widget (solid orange / solid blue / cross-fade / Reduce Motion violet, plus popover mock).

## Design decisions

- Provider colors reuse the allowance-pill palette exactly, so icon, rows, and pills match. Azure reads as the "blue" John wanted for Codex (not `.controlAccentColor`, which follows the user's system accent).
- Provider color applies ONLY to the working state (thinking / usingTool). All other states are untouched: permission yellow, completed and celebration green, disconnected gray, idle neutral, low-allowance orange badge dot.
- Both working: slow cross-fade blue -> orange -> blue while rotating. Under Reduce Motion, no cross-fade; show a static violet blend (`#8C82AB`, the orange/blue midpoint) so it still reads as "both."
- Summary line names the active agents: "Claude working", "Codex working", or "Claude and Codex working". Permission state keeps "N agents need you" (attention, not which is working). Falls back to the current count text when nothing is active.
- "Active provider" = a provider with at least one session in thinking or usingTool. Permission does not count as working.
- One source of truth for the palette: a small `ProviderColor` helper exposing both `NSColor` (AppKit) and `Color` (SwiftUI) per provider. `AllowanceSectionView`, `SessionRowView`, and `StatusPresentation` all read from it.

## Global constraints

- macOS 14.0 deployment target; CI builds Xcode 16.4. Guard newer symbols with `#if compiler(...)`, not just `#available`. No macOS 26-only symbols unguarded.
- No em dashes in user-facing strings.
- Surgical changes; match existing style. No version bump, no release, no push until John's OK.
- Cross-fade must be gated on Reduce Motion, and must stop when the popover/app stops (no leaked timers).

## Tasks

### Task 1: Core — active providers
- Add `activeProviders: Set<AgentProvider>` to `ResolvedSessions` in `Sources/AgenticGlowCore/State/SessionSnapshot.swift`; populate it in `SessionResolver.resolve` from sessions whose phase is `.thinking` or `.usingTool`.
- Tests first in `Tests/AgenticGlowCoreTests/SessionResolverTests.swift`: none working -> empty; only a Claude thinking/usingTool session -> `[.claude]`; only Codex -> `[.codex]`; both -> `[.claude, .codex]`; permission-only or idle/completed/disconnected -> empty.
- [x] Failing tests, implement, pass -> verified: SessionResolverTests 14/14 green (5 new: none/Claude-only/Codex-only/both/permission-excluded); StatusPresentationTests 11/11 still green after adding the field

### Task 2: Shared provider palette
- Add `ProviderColor` helper (app layer) with `static func nsColor(for: AgentProvider) -> NSColor` and `static func color(for: AgentProvider) -> Color`, plus the violet "both" blend for Reduce Motion. Values: Claude `#D97857`, Codex `#408CFF`, blend `#8C82AB`.
- Point `AllowanceSectionView.tint` and `SessionRowView.color` (working state) at it; remove their local color literals.
- [x] Implement -> verified: `ProviderColor` added; `AllowanceSectionView.tint` now reads from it. ProviderColorTests 3/3 lock the sRGB values; AllowancePresentationTests still green (pills unchanged). Note: `SessionRowView` color change moved to Task 5 (it was `.accentColor`, a behavior change, not a pure refactor).

### Task 3: Presentation — provider tints on the icon
- `StatusPresentation`: in the `.usingTool` / `.thinking` case, expose the active provider colors from `resolved.activeProviders` as `activeTints: [NSColor]` (0, 1, or 2 entries) instead of the flat `.controlAccentColor`. Keep `color` for non-working states. Struct stays `Equatable`.
- Tests in `Tests/AgenticGlowAppTests/StatusPresentationTests.swift`: working {claude} -> `[orange]`; {codex} -> `[blue]`; both -> `[orange, blue]`; permission -> yellow unchanged; idle/completed unchanged.
- [x] Failing tests, implement, pass -> verified: `activeTints: [NSColor]` added (Claude-then-Codex order, empty unless dominant phase is working). StatusPresentationTests 16/16 green (5 new: Claude-only, Codex-only, both-order, permission-empty, idle-empty).

### Task 4: Controller — cross-fade
- `StatusItemController.update()`: set tint from `activeTints` — 1 color -> solid; 2 colors -> start cross-fade; 0 -> `presentation.color`. Celebration (green) still wins.
- Cross-fade: a repeating `Task` interpolating `symbolView.contentTintColor` between the two colors on a sine ease (~3s each way, ~50ms steps). Store as `tintCrossfadeTask`; cancel on state change and in `stop()`. Under Reduce Motion, no task; set the static violet blend.
- Rotation (`configureAnimation`) unchanged; already gated on `presentation.animates`.
- [x] Implement -> verified: build succeeds. `applyTint` handles solid (1 tint) / cross-fade (2 tints) / fallback (0), celebration green wins. Cross-fade is a `tintCrossfadeTask` (cosine ease, 3s each way), cancelled on state change, in `stop()`, and when a celebration starts. Reduce Motion sets the static violet blend, no task. Runtime/visual confirmation pending Task 6.

### Task 5: Session list clarity
- `SessionRowView.color`: for `.thinking` / `.usingTool`, return the provider color via `ProviderColor`; other phases unchanged.
- `SessionListView.summary`: when `permissionCount == 0` and something is working, name providers from `model.resolved.activeProviders` ("Claude working" / "Codex working" / "Claude and Codex working"); permission and count branches unchanged.
- [x] Implement -> verified: build succeeds. `SessionRowView` working icon now tints by provider; `SessionListView.summary` names providers ("Claude working" / "Codex working" / "Claude and Codex working"), permission and count branches unchanged. Full unit suite 205/205 green. Visual confirmation pending Task 6.

### Task 6: Verify end to end
- Run full Core + app test suite; privacy gate passes.
- Launch and capture the real menu bar icon in each working state (Claude-only orange, Codex-only blue, both cross-fading) plus Reduce Motion violet, and the popover summary + colored rows, in Light and Dark. Add or adjust a UI-test fixture that puts both providers in a working (thinking/usingTool) phase, since the current `signals` fixture pairs Claude permission with Codex thinking.
- [x] All tests pass (205), screenshots confirm each state -> verified: popover both-working captured in Light and Dark ("Claude and Codex working" summary, blue Codex row, orange Claude row). Added a `both-working` UI fixture. Menu bar icon captured cross-fading blue -> orange, and the permission state now shows yellow.

## Follow-ups discovered during verification (2026-07-08)

- Menu bar icon color did not render: macOS flattens status-bar TEMPLATE images to monochrome and ignores `contentTintColor` (pre-existing; the old yellow/green/blue states were invisible too). Fixed by baking the color into a NON-template symbol image via `NSImage.SymbolConfiguration(paletteColors:)`; the cross-fade regenerates the image per frame. Verified the icon now shows blue/orange/yellow. This also makes the existing permission/completed colors actually appear.
- Reduce Motion static-violet path: could not flip the live accessibility setting via `defaults write` (the system caches it), so not captured on screen. Verified by construction: it calls the same proven `setSymbol` with `ProviderColor.bothBlend`, gated by the same `model.reduceMotion` that already gates rotation. Confirm live if desired by toggling Reduce Motion in System Settings.
- Incident line: made neutral (`.secondary`, keeps the warning triangle) so orange stays "Claude" in the color language.
- Incident severity: `StatusPageNormalizer` now only reports `major`/`critical` as incidents; `none`/`minor`/`maintenance` are operational. This kills a false alarm where OpenAI's unrelated FedRAMP component (minor) implied Codex was down.

## Current work (2026-07-12): permission + working dissolve

Plan: docs/superpowers/plans/2026-07-12-permission-working-dissolve.md

- [x] Task 1: PermissionDissolve timeline -> verified: 5/5 unit tests
- [x] Task 2: StatusPresentation combined state -> verified: 21/21 StatusPresentationTests
- [x] Task 3: Controller per-frame dissolve rendering -> verified: full unit suite 78/78
- [x] Task 4: Fixture + visual verification -> verified: 14-frame capture series shows dwells, soft fades, continuous rotation and color sweep; 7/7 UI tests signed
- [x] Final whole-branch review -> verdict READY, no blocking findings
