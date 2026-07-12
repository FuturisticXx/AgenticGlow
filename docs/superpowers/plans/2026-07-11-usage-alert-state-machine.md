# Usage Alert State Machine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send one low-usage warning and one exhausted alert per provider window, replace the earlier warning at 0 percent, include reset-time guidance, and re-arm only after healthy recovery.

**Architecture:** Replace reset-timestamp deduplication with a state machine in `AgenticGlowCore`. The app notification service consumes semantic low or exhausted events and owns localized copy plus the stable Notification Center identifier.

**Tech Stack:** Swift 6, Foundation, UserNotifications, XCTest, XcodeGen, macOS 14+

**Status:** Complete. Implemented in commits `a0b01b7` and `e0824eb`, verified with 234 non-UI tests, and released in v0.4.7.

## Global Constraints

- Keep `AllowanceWarning.thresholdPercentLeft` at exactly `10`.
- Keep the existing `notifyQuotaLow` preference. Add no new toggle.
- Use reset timestamps only for display copy, never for deduplication identity.
- Use one stable notification identifier per provider and allowance window.
- Store no raw provider responses, usage history, prompts, responses, commands, or tool arguments.
- Add no notification actions, animation, dependency, database access, or provider request.
- Use no em dashes in source comments, documentation, or user-facing copy.
- Run unit tests with `CODE_SIGNING_ALLOWED=NO` to avoid Keychain prompts.

---

### Task 1: Replace timestamp deduplication with semantic alert transitions

**Files:**
- Modify: `Sources/AgenticGlowCore/Notifications/NotificationPolicy.swift`
- Modify: `Sources/AgenticGlowApp/Services/AgentNotificationService.swift`
- Modify: `Tests/AgenticGlowCoreTests/NotificationPolicyTests.swift`
- Modify: `gotdone.md`

**Interfaces:**
- Consumes: `ProviderAllowance`, `AllowanceWarning.Window`, `AgentProvider`
- Produces: `QuotaAlert.Level`, `QuotaAlert.window`, and `QuotaAlertTracker.newAlerts(provider:allowance:) -> [QuotaAlert]`

- [x] **Step 1: Replace the old reset-window tests with failing transition tests**

Keep the permission tests unchanged. Replace the quota tests with:

```swift
func testQuotaTrackerWarnsOnceThenAlertsOnceWhenExhausted() {
    var tracker = QuotaAlertTracker()
    XCTAssertEqual(
        tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 92)).map(\.level),
        [.low]
    )
    XCTAssertEqual(
        tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 100)).map(\.level),
        [.exhausted]
    )
    XCTAssertEqual(
        tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 100)),
        []
    )
}

func testQuotaTrackerFirstObservationAtZeroEmitsOnlyExhausted() {
    var tracker = QuotaAlertTracker()
    let alerts = tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 100))
    XCTAssertEqual(alerts.map(\.level), [.exhausted])
}

func testQuotaTrackerIgnoresMovingResetTimestampDuringSameLowState() {
    var tracker = QuotaAlertTracker()
    let first = allowance(currentUsed: 95, currentResetAt: now.addingTimeInterval(3_600))
    let moved = allowance(currentUsed: 95, currentResetAt: now.addingTimeInterval(3_900))
    _ = tracker.newAlerts(provider: .claude, allowance: first)
    XCTAssertEqual(tracker.newAlerts(provider: .claude, allowance: moved), [])
}

func testQuotaTrackerStaysExhaustedUntilHealthyRecovery() {
    var tracker = QuotaAlertTracker()
    _ = tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 100))
    XCTAssertEqual(
        tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 95)),
        []
    )
    _ = tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 40))
    XCTAssertEqual(
        tracker.newAlerts(provider: .claude, allowance: allowance(currentUsed: 95)).map(\.level),
        [.low]
    )
}

func testQuotaTrackerKeepsWindowsAndProvidersIndependent() {
    var tracker = QuotaAlertTracker()
    let bothLow = allowance(currentUsed: 95, weeklyUsed: 95)
    let codexAlerts = tracker.newAlerts(provider: .codex, allowance: bothLow)
    XCTAssertEqual(codexAlerts.map(\.window.label), ["5h", "week"])
    XCTAssertEqual(codexAlerts.map(\.level), [.low, .low])
    XCTAssertEqual(
        tracker.newAlerts(provider: .claude, allowance: bothLow).map(\.level),
        [.low, .low]
    )
}
```

Expand the allowance helper to accept `weeklyUsed`, `currentResetAt`, and `weeklyResetAt` independently.

- [x] **Step 2: Run the focused core test and verify RED**

```bash
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS' \
  -only-testing:AgenticGlowCoreTests/NotificationPolicyTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `QuotaAlert` and `QuotaAlert.Level` do not exist and `newAlerts` still returns `[AllowanceWarning.Window]`.

- [x] **Step 3: Implement the semantic tracker**

Replace the existing quota tracker with:

```swift
public struct QuotaAlert: Equatable, Sendable {
    public enum Level: Equatable, Sendable {
        case low
        case exhausted
    }

    public let level: Level
    public let window: AllowanceWarning.Window
}

public struct QuotaAlertTracker: Sendable {
    private struct Key: Hashable, Sendable {
        let provider: AgentProvider
        let windowLabel: String
    }

    private var states: [Key: QuotaAlert.Level] = [:]

    public init() {}

    public mutating func newAlerts(
        provider: AgentProvider,
        allowance: ProviderAllowance
    ) -> [QuotaAlert] {
        observations(in: allowance).compactMap { window in
            let key = Key(provider: provider, windowLabel: window.label)
            guard window.percentLeft < AllowanceWarning.thresholdPercentLeft else {
                states.removeValue(forKey: key)
                return nil
            }
            let current: QuotaAlert.Level = window.percentLeft <= 0 ? .exhausted : .low
            let previous = states[key]
            if previous == .exhausted { return nil }
            states[key] = current
            if previous == current { return nil }
            return QuotaAlert(level: current, window: window)
        }
    }

    private func observations(in allowance: ProviderAllowance) -> [AllowanceWarning.Window] {
        var windows: [AllowanceWarning.Window] = []
        if let left = allowance.currentPercentLeft {
            windows.append(.init(
                label: allowance.currentWindowLabel,
                percentLeft: left,
                resetAt: allowance.currentResetAt
            ))
        }
        if let left = allowance.weeklyPercentLeft {
            windows.append(.init(
                label: "week",
                percentLeft: left,
                resetAt: allowance.weeklyResetAt
            ))
        }
        return windows
    }
}
```

Mechanically unwrap `alert.window` in `AgentNotificationService` so the existing copy continues to compile. Do not change copy or branch on `alert.level` until Task 2.

- [x] **Step 4: Run the focused core test and verify GREEN**

Run the command from Step 2.

Expected: `NotificationPolicyTests` passes with zero failures.

- [x] **Step 5: Record and commit the core behavior**

Add a `gotdone.md` entry with the transition behavior and focused test result.

```bash
git add Sources/AgenticGlowCore/Notifications/NotificationPolicy.swift \
  Tests/AgenticGlowCoreTests/NotificationPolicyTests.swift gotdone.md
git commit -m "fix: dedupe quota alerts by usage state"
```

---

### Task 2: Format helpful low and exhausted notifications

**Files:**
- Modify: `Sources/AgenticGlowApp/Services/AgentNotificationService.swift`
- Modify: `Tests/AgenticGlowAppTests/AgentNotificationServiceTests.swift`
- Modify: `gotdone.md`

**Interfaces:**
- Consumes: `QuotaAlertTracker.newAlerts(provider:allowance:) -> [QuotaAlert]`
- Produces: reset-time copy and stable IDs through `UserNotificationScheduling.add`

- [x] **Step 1: Replace the existing quota-copy tests with failing copy and replacement tests**

Replace `testQuotaAlertFiresOncePerWindowWithWindowCopy` and `testWeeklyWindowUsesWeeklyCopy` so their old bodies cannot conflict with the reset-time copy. Add `id` to `FakeScheduler.Added`, store it in `add`, inject a deterministic reset formatter through `makeService`, and add:

```swift
func testQuotaLowIncludesResetTime() async {
    let scheduler = FakeScheduler()
    let service = makeService(scheduler: scheduler, resetTime: { _ in "12:50 AM" })
    service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 92))
    await service.drain()
    XCTAssertEqual(scheduler.added.first?.id, "quota.claude.5h")
    XCTAssertEqual(scheduler.added.first?.title, "Claude usage running low")
    XCTAssertEqual(
        scheduler.added.first?.body,
        "5-hour window: 8% left. Resets at 12:50 AM."
    )
}

func testQuotaExhaustedReplacesLowNotification() async {
    let scheduler = FakeScheduler()
    let service = makeService(scheduler: scheduler, resetTime: { _ in "12:50 AM" })
    service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 92))
    service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 100))
    await service.drain()
    XCTAssertEqual(scheduler.added.map(\.id), ["quota.claude.5h", "quota.claude.5h"])
    XCTAssertEqual(scheduler.added.last?.title, "Claude 5-hour usage exhausted")
    XCTAssertEqual(scheduler.added.last?.body, "Available again at 12:50 AM.")
}

func testQuotaExhaustedWithoutResetTimeUsesFallback() async {
    let scheduler = FakeScheduler()
    let service = makeService(scheduler: scheduler)
    service.allowanceUpdated(
        provider: .codex,
        allowance: allowance(currentUsed: 100, currentResetAt: nil)
    )
    await service.drain()
    XCTAssertEqual(scheduler.added.first?.title, "Codex 5-hour usage exhausted")
    XCTAssertEqual(scheduler.added.first?.body, "No usage remaining in this window.")
}

func testRepeatedExhaustedReadingsScheduleOnce() async {
    let scheduler = FakeScheduler()
    let service = makeService(scheduler: scheduler)
    service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 100))
    service.allowanceUpdated(provider: .claude, allowance: allowance(currentUsed: 100))
    await service.drain()
    XCTAssertEqual(scheduler.added.count, 1)
}
```

- [x] **Step 2: Run the focused service test and verify RED**

```bash
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS' \
  -only-testing:AgenticGlowAppTests/AgentNotificationServiceTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation or assertions fail because the service has no reset formatter or exhausted copy and the fake scheduler does not retain IDs.

- [x] **Step 3: Add reset formatting and semantic copy**

Add this initializer dependency:

```swift
private let resetTime: (Date) -> String

init(
    scheduler: any UserNotificationScheduling,
    permissionEnabled: @escaping () -> Bool,
    quotaEnabled: @escaping () -> Bool,
    resetTime: @escaping (Date) -> String = {
        $0.formatted(date: .omitted, time: .shortened)
    },
    activate: @escaping (String) -> Void
)
```

Then format every semantic alert as follows:

```swift
let windowName = alert.window.label == "week" ? "Weekly" : "5-hour"
let id = "quota.\(provider.rawValue).\(alert.window.label)"
switch alert.level {
case .low:
    title = "\(provider.notificationName) usage running low"
    let reset = alert.window.resetAt.map { " Resets at \(resetTime($0))." } ?? ""
    body = "\(windowName) window: \(Int(alert.window.percentLeft.rounded()))% left.\(reset)"
case .exhausted:
    let titleWindow = windowName == "Weekly" ? "weekly" : "5-hour"
    title = "\(provider.notificationName) \(titleWindow) usage exhausted"
    body = alert.window.resetAt.map { "Available again at \(resetTime($0))." }
        ?? "No usage remaining in this window."
}
```

Schedule both levels with `id`, ensuring the exhausted request replaces the low request.

- [x] **Step 4: Run the focused service test and verify GREEN**

Run the command from Step 2.

Expected: `AgentNotificationServiceTests` passes with zero failures.

- [x] **Step 5: Record and commit the app behavior**

Add a `gotdone.md` entry with copy, replacement behavior, and focused test result.

```bash
git add Sources/AgenticGlowApp/Services/AgentNotificationService.swift \
  Tests/AgenticGlowAppTests/AgentNotificationServiceTests.swift gotdone.md
git commit -m "feat: alert once when usage is exhausted"
```

---

### Task 3: Run the full non-UI verification surface

**Files:**
- Modify: `gotdone.md`

**Interfaces:**
- Consumes: completed core and app notification behavior
- Produces: repository-wide verification evidence

- [x] **Step 1: Verify deterministic project generation**

```bash
xcodegen generate
git diff --exit-code -- AgenticGlow.xcodeproj/project.pbxproj
```

Expected: both commands exit `0` and the generated project is unchanged.

- [x] **Step 2: Run the complete non-UI suite**

```bash
xcodebuild test \
  -project AgenticGlow.xcodeproj \
  -scheme AgenticGlow \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  -skip-testing:AgenticGlowUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` with zero failures and no Keychain prompt.

- [x] **Step 3: Verify helper isolation, privacy, and diff hygiene**

```bash
Scripts/verify-standalone-helper.sh \
  build/DerivedData/Build/Products/Debug/AgenticGlow.app/Contents/Resources/bin/agenticglow-event
Scripts/verify-privacy.sh
git diff --check
```

Expected: all commands exit `0`.

- [x] **Step 4: Record final evidence**

Add exact test counts and verification results to `gotdone.md`.

```bash
git add gotdone.md
git commit -m "docs: record usage alert verification"
```

Expected: `git status --short` is clean after the commit.
