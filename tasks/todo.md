# v0.3.0: Notifications, Low-Allowance Badge, Incident Status, Reset Celebration (2026-07-08)

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

John asked to cut the release build containing the Dark Mode popover fix. Since
v0.1.1, main also holds the popover aura, allowance bar redesign, elapsed-seconds
display, refreshed icon, and the Codex bundled-binary allowance fix; that set was
already staged privately as 0.2.0, so this release is 0.2.0.

- [x] Signed universal release build via Scripts/build-release.sh 0.2.0 -> verified: gates passed, codesign strict passed, lipo shows x86_64 arm64
- [x] DMG: create, sign, notarize, staple via Scripts/create-dmg.sh 0.2.0 -> verified: notarization Accepted, staple validated, spctl accepts app and DMG as Notarized Developer ID; DMG SHA-256 9b990455fa7155d13bb4df61137e0fd6cf614e62fe08cd6547b96b901d7ed512
- [x] Installed to /Applications replacing v0.1.1, relaunched -> verified: Info.plist reads 0.2.0, dark popover screenshot from installed app shows scrim + light-palette aura
- [x] John confirmed publication: GitHub release v0.2.0 published from tag at `09dabd6`, downloaded asset checksum/staple/Gatekeeper verified, cask bumped on main (`3b2575f`) and tap updated (`5c21667`)

# Fix: Dark Mode popover too light (2026-07-05)

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
