# Global Popover Shortcut + Repair Auto-Restart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global Command+Shift+A hotkey that toggles AgenticGlow's menu bar popover, and make Setup's Repair action restart the app on purpose (with a visible message) immediately afterward, so the pre-existing AppKit crash confirmed this session never has a chance to surface as an unexplained disappearance.

**Architecture:** `SetupViewModel.repair()` gains a `.restarting` phase and an injected `requestRestart` closure, called after a short injectable delay. `AppDelegate` wires that closure to spawn a fresh app instance via `NSWorkspace.openApplication` and terminate itself, leaving a one-shot `UserDefaults` flag that the next launch consumes to force-reopen Setup. Setup's `.task` gains a real status check so the reopened window shows truthful state instead of a stale default. The global hotkey is a self-contained Carbon `RegisterEventHotKey` registration in `AppDelegate`, wired to `StatusItemController`'s existing (now internal) toggle method.

**Tech Stack:** Swift, SwiftUI, AppKit, Carbon (HIToolbox), XCTest.

## Global Constraints

- Shortcut is Command+Shift+A (not Control+A — collides with system-wide beginning-of-line text editing). Verbatim from the spec.
- The shortcut toggles the popover (open if closed, close if open) — matches "same as clicking the menu bar icon."
- Only `SetupViewModel.repair()` triggers a restart. `install()` and `remove()` must not.
- Restart shows "Repair successful — restarting AgenticGlow…" for ~1.5s (production default) before relaunching. (Revised after live testing: 1.5s was too short to notice and the plain-text-in-a-crowded-row layout truncated to unreadable text — shipped as a 3s delay with `.restarting` replacing the entire row with a styled orange `Label` and hiding the buttons.)
- After relaunch, Setup automatically reopens showing the real (already-correct) install state — not a faked "just repaired" state reconstructed across the process boundary.
- Hotkey registration failure and restart-launch failure are both soft failures: log and continue running, never leave the user with no working app.
- No new entitlements or Info.plist keys — the app is already unsandboxed (`Config/AgenticGlow.entitlements` has no `com.apple.security.app-sandbox` key) and Carbon hotkey registration needs none.
- All new `SetupViewModel` init parameters must have defaults — three existing call sites (`AppDelegate.swift`, `UITestSessionStore.swift`, `SetupViewModelTests.swift`) must keep compiling unchanged where they don't need the new behavior.

---

### Task 1: Add `SetupPhase.restarting` and its Setup UI text

**Files:**
- Modify: `Sources/AgenticGlowApp/Setup/SetupViewModel.swift:5-12` (the `SetupPhase` enum)
- Modify: `Sources/AgenticGlowApp/Setup/SetupView.swift:54-63` (the `statusText(_:)` switch)

**Interfaces:**
- Produces: `SetupPhase.restarting` — a new case later tasks set from `SetupViewModel.repair()` and read from `SetupView`.

This task has no new logic to test — it's an enum case plus the matching exhaustive-switch text. Swift's exhaustiveness check means both edits must land together: adding the case without the switch case is a compile error, and the resulting behavior is directly visible in the existing test suite (which must still pass) and in `SetupView`'s UI copy.

- [ ] **Step 1: Add the enum case**

In `Sources/AgenticGlowApp/Setup/SetupViewModel.swift`, change:

```swift
enum SetupPhase: Equatable {
    case unavailable
    case ready
    case installing
    case needsTrust
    case installed
    case failed(String)
}
```

to:

```swift
enum SetupPhase: Equatable {
    case unavailable
    case ready
    case installing
    case needsTrust
    case installed
    case restarting
    case failed(String)
}
```

- [ ] **Step 2: Add the matching UI text**

In `Sources/AgenticGlowApp/Setup/SetupView.swift`, change:

```swift
    private func statusText(_ phase: SetupPhase) -> String {
        switch phase {
        case .unavailable: "Not detected"
        case .ready: "Ready to install"
        case .installing: "Installing"
        case .needsTrust: "Installed, trust required"
        case .installed: "Installed"
        case .failed(let message): message
        }
    }
```

to:

```swift
    private func statusText(_ phase: SetupPhase) -> String {
        switch phase {
        case .unavailable: "Not detected"
        case .ready: "Ready to install"
        case .installing: "Installing"
        case .needsTrust: "Installed, trust required"
        case .installed: "Installed"
        case .restarting: "Repair successful — restarting AgenticGlow…"
        case .failed(let message): message
        }
    }
```

- [ ] **Step 3: Build and run the existing test suite to confirm no regression**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild build -project AgenticGlow.xcodeproj -scheme AgenticGlow CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/SetupViewModelTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -20`

Expected: `Executed 6 tests, with 0 failures`

- [ ] **Step 4: Commit**

```bash
git add Sources/AgenticGlowApp/Setup/SetupViewModel.swift Sources/AgenticGlowApp/Setup/SetupView.swift
git commit -m "feat: add SetupPhase.restarting case and its Setup UI text"
```

---

### Task 2: `SetupViewModel.syncPhaseFromCurrentStatus()`

**Files:**
- Modify: `Sources/AgenticGlowApp/Setup/SetupViewModel.swift` (add method, after `refreshDiagnostics()`)
- Modify: `Tests/AgenticGlowAppTests/SetupViewModelTests.swift` (extend `SetupRecorder`, add 3 tests)

**Interfaces:**
- Consumes: `ProviderIntegrationManaging.status() throws -> IntegrationStatus` (existing, `Sources/AgenticGlowCore/Integrations/IntegrationStatus.swift:25-31`). `IntegrationStatus` has `installed: Bool` and `requiresTrustReview: Bool` (existing, same file lines 3-23).
- Produces: `func syncPhaseFromCurrentStatus()` on `SetupViewModel` — sets `phase` to `.installed` or `.needsTrust` when `integration.status()` reports the provider is already installed; leaves `phase` untouched otherwise (including when `status()` throws). Task 3 calls this from `SetupView`.

Today, `SetupRecorder.status()` (in the test file) returns a hardcoded `IntegrationStatus`. Make it configurable first so each new test can control what "current status" looks like without touching the other tests' expectations.

- [ ] **Step 1: Make `SetupRecorder.status()` configurable, preserving today's default**

In `Tests/AgenticGlowAppTests/SetupViewModelTests.swift`, change:

```swift
    func status() throws -> IntegrationStatus {
        .init(
            provider: .codex,
            installed: true,
            requiresTrustReview: true,
            installedEvents: [],
            issue: nil
        )
    }
```

to:

```swift
    var statusOverride = IntegrationStatus(
        provider: .codex,
        installed: true,
        requiresTrustReview: true,
        installedEvents: [],
        issue: nil
    )

    func status() throws -> IntegrationStatus { statusOverride }
```

This is a pure refactor — the default value is identical to today's hardcoded return, so every existing test in this file keeps passing unchanged.

- [ ] **Step 2: Write the three failing tests**

Add to `Tests/AgenticGlowAppTests/SetupViewModelTests.swift`, inside `final class SetupViewModelTests`:

```swift
    func testSyncPhaseFromCurrentStatusShowsInstalledWhenAlreadyConfigured() {
        let recorder = SetupRecorder()
        recorder.statusOverride = IntegrationStatus(
            provider: .codex,
            installed: true,
            requiresTrustReview: false,
            installedEvents: [],
            issue: nil
        )
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder
        )

        model.syncPhaseFromCurrentStatus()

        XCTAssertEqual(model.phase, .installed)
    }

    func testSyncPhaseFromCurrentStatusShowsNeedsTrustWhenTrustReviewOutstanding() {
        let recorder = SetupRecorder()
        recorder.statusOverride = IntegrationStatus(
            provider: .codex,
            installed: true,
            requiresTrustReview: true,
            installedEvents: [],
            issue: nil
        )
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder
        )

        model.syncPhaseFromCurrentStatus()

        XCTAssertEqual(model.phase, .needsTrust)
    }

    func testSyncPhaseFromCurrentStatusLeavesPhaseUnchangedWhenNotInstalled() {
        let recorder = SetupRecorder()
        recorder.statusOverride = IntegrationStatus(
            provider: .codex,
            installed: false,
            requiresTrustReview: false,
            installedEvents: [],
            issue: nil
        )
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder
        )

        model.syncPhaseFromCurrentStatus()

        XCTAssertEqual(model.phase, .ready)
    }
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/SetupViewModelTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -30`

Expected: build error — `value of type 'SetupViewModel' has no member 'syncPhaseFromCurrentStatus'`

- [ ] **Step 4: Implement the method**

In `Sources/AgenticGlowApp/Setup/SetupViewModel.swift`, add after `refreshDiagnostics()`:

```swift
    func syncPhaseFromCurrentStatus() {
        guard let status = try? integration.status(), status.installed else { return }
        phase = status.requiresTrustReview ? .needsTrust : .installed
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/SetupViewModelTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -30`

Expected: `Executed 9 tests, with 0 failures`

- [ ] **Step 6: Commit**

```bash
git add Sources/AgenticGlowApp/Setup/SetupViewModel.swift Tests/AgenticGlowAppTests/SetupViewModelTests.swift
git commit -m "feat: add SetupViewModel.syncPhaseFromCurrentStatus()"
```

---

### Task 3: Wire `syncPhaseFromCurrentStatus()` into Setup's appear

**Files:**
- Modify: `Sources/AgenticGlowApp/Setup/SetupView.swift:28-32` (the `.task` modifier)

**Interfaces:**
- Consumes: `SetupViewModel.syncPhaseFromCurrentStatus()` (Task 2).

This is SwiftUI view wiring with no existing unit-test coverage in this file (the `.task` block isn't exercised by `SetupViewModelTests`, which only constructs the view model directly) — it's covered by Task 10's live verification instead.

- [ ] **Step 1: Call the new method after version detection**

In `Sources/AgenticGlowApp/Setup/SetupView.swift`, change:

```swift
        .task {
            async let claudeVersion: Void = claude.detectVersion()
            async let codexVersion: Void = codex.detectVersion()
            _ = await (claudeVersion, codexVersion)
        }
```

to:

```swift
        .task {
            async let claudeVersion: Void = claude.detectVersion()
            async let codexVersion: Void = codex.detectVersion()
            _ = await (claudeVersion, codexVersion)
            claude.syncPhaseFromCurrentStatus()
            codex.syncPhaseFromCurrentStatus()
        }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild build -project AgenticGlow.xcodeproj -scheme AgenticGlow CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Sources/AgenticGlowApp/Setup/SetupView.swift
git commit -m "feat: sync Setup phase from real status when Setup appears"
```

---

### Task 4: `SetupViewModel.repair()` restart flow

**Files:**
- Modify: `Sources/AgenticGlowApp/Setup/SetupViewModel.swift` (new init params, `repair()` body)
- Modify: `Tests/AgenticGlowAppTests/SetupViewModelTests.swift` (3 new tests)

**Interfaces:**
- Produces: `SetupViewModel.init(..., requestRestart: @escaping () -> Void = { }, restartDelay: Duration = .seconds(1.5))`. After `repair()` succeeds, `phase` becomes `.restarting`, then after `restartDelay` the `requestRestart` closure is called. `install()` and `remove()` never call it. Task 6 wires the production closure; tests pass `restartDelay: .zero` so the suite stays fast. (Note: shipped default is `.seconds(3)`, and `requestRestart` was later changed to `() async -> Bool` so `repair()` can recover the phase when the relaunch fails — see the post-review fix.)

- [ ] **Step 1: Write the three failing tests**

Add to `Tests/AgenticGlowAppTests/SetupViewModelTests.swift`:

```swift
    func testRepairRequestsRestartAfterSuccess() async {
        let recorder = SetupRecorder()
        var restartRequested = false
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder,
            requestRestart: { restartRequested = true },
            restartDelay: .zero
        )

        await model.repair()

        XCTAssertTrue(restartRequested)
    }

    func testInstallDoesNotRequestRestart() async {
        let recorder = SetupRecorder()
        var restartRequested = false
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder,
            requestRestart: { restartRequested = true },
            restartDelay: .zero
        )

        await model.install()

        XCTAssertFalse(restartRequested)
    }

    func testRemoveDoesNotRequestRestart() {
        let recorder = SetupRecorder()
        var restartRequested = false
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder,
            requestRestart: { restartRequested = true },
            restartDelay: .zero
        )

        model.remove()

        XCTAssertFalse(restartRequested)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/SetupViewModelTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -30`

Expected: build error — `incorrect argument label` / `extra argument 'requestRestart' in call` (the init doesn't accept these parameters yet)

- [ ] **Step 3: Add the new init parameters**

In `Sources/AgenticGlowApp/Setup/SetupViewModel.swift`, change:

```swift
    private let lastEvent: () -> Date?
    private let setIntegrationEnabled: (Bool) -> Void
    var phase: SetupPhase
    var integrationStatus: IntegrationStatus?
    var lastEventAt: Date?

    init(
        provider: AgentProvider,
        executableURL: URL?,
        helperInstaller: HelperInstalling,
        integration: ProviderIntegrationManaging,
        syntheticEventService: SyntheticEventTesting,
        lastEvent: @escaping () -> Date? = { nil },
        setIntegrationEnabled: @escaping (Bool) -> Void = { _ in }
    ) {
        self.provider = provider
        self.executableURL = executableURL
        self.detectedVersion = nil
        self.helperInstaller = helperInstaller
        self.integration = integration
        self.syntheticEventService = syntheticEventService
        self.lastEvent = lastEvent
        self.setIntegrationEnabled = setIntegrationEnabled
        self.phase = executableURL == nil ? .unavailable : .ready
    }
```

to:

```swift
    private let lastEvent: () -> Date?
    private let setIntegrationEnabled: (Bool) -> Void
    private let requestRestart: () -> Void
    private let restartDelay: Duration
    var phase: SetupPhase
    var integrationStatus: IntegrationStatus?
    var lastEventAt: Date?

    init(
        provider: AgentProvider,
        executableURL: URL?,
        helperInstaller: HelperInstalling,
        integration: ProviderIntegrationManaging,
        syntheticEventService: SyntheticEventTesting,
        lastEvent: @escaping () -> Date? = { nil },
        setIntegrationEnabled: @escaping (Bool) -> Void = { _ in },
        requestRestart: @escaping () -> Void = { },
        restartDelay: Duration = .seconds(1.5)  // shipped default: .seconds(3), see note above
    ) {
        self.provider = provider
        self.executableURL = executableURL
        self.detectedVersion = nil
        self.helperInstaller = helperInstaller
        self.integration = integration
        self.syntheticEventService = syntheticEventService
        self.lastEvent = lastEvent
        self.setIntegrationEnabled = setIntegrationEnabled
        self.requestRestart = requestRestart
        self.restartDelay = restartDelay
        self.phase = executableURL == nil ? .unavailable : .ready
    }
```

- [ ] **Step 4: Add the restart sequence to `repair()`**

In `Sources/AgenticGlowApp/Setup/SetupViewModel.swift`, change:

```swift
    func repair() async {
        phase = .installing
        do {
            try helperInstaller.install()
            try integration.repair()
            phase = provider == .codex ? .needsTrust : .installed
            setIntegrationEnabled(true)
            refreshDiagnostics()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
```

to:

```swift
    func repair() async {
        phase = .installing
        do {
            try helperInstaller.install()
            try integration.repair()
            phase = provider == .codex ? .needsTrust : .installed
            setIntegrationEnabled(true)
            refreshDiagnostics()
            phase = .restarting
            try? await Task.sleep(for: restartDelay)
            requestRestart()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/SetupViewModelTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -30`

Expected: `Executed 12 tests, with 0 failures`

- [ ] **Step 6: Commit**

```bash
git add Sources/AgenticGlowApp/Setup/SetupViewModel.swift Tests/AgenticGlowAppTests/SetupViewModelTests.swift
git commit -m "feat: request a restart after a successful Repair"
```

---

### Task 5: Make `StatusItemController.togglePopover()` internal

**Files:**
- Modify: `Sources/AgenticGlowApp/MenuBar/StatusItemController.swift` (the `togglePopover()` declaration, currently `private`, exact line found via grep since this file changes independently of this plan)

**Interfaces:**
- Produces: `func togglePopover()` on `StatusItemController`, same behavior as today, just no longer `private` — Task 8's hotkey handler calls it.

- [ ] **Step 1: Find the exact current line**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && grep -n "private func togglePopover" Sources/AgenticGlowApp/MenuBar/StatusItemController.swift`

Expected output: `122:    @objc private func togglePopover() {` (line number may drift if the file changed since this plan was written — use whatever line the grep reports)

- [ ] **Step 2: Drop `private`**

Change:

```swift
    @objc private func togglePopover() {
```

to:

```swift
    @objc func togglePopover() {
```

Leave the method body untouched — this is a visibility-only change.

- [ ] **Step 3: Build to verify it compiles**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild build -project AgenticGlow.xcodeproj -scheme AgenticGlow CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Sources/AgenticGlowApp/MenuBar/StatusItemController.swift
git commit -m "refactor: make StatusItemController.togglePopover() internal"
```

---

### Task 6: `AppDelegate` relaunch mechanism

**Files:**
- Modify: `Sources/AgenticGlowApp/AppDelegate.swift` (new `relaunch()` method; wire `requestRestart` into `claudeModel`/`codexModel`)

**Interfaces:**
- Consumes: `SetupViewModel.init(..., requestRestart:)` (Task 4).
- Produces: `AppDelegate.relaunch()` — sets the `reopenSetupAfterRestart` `UserDefaults` flag, spawns a new AgenticGlow instance, and terminates the current one only if the new instance launched successfully. Task 7 consumes the flag on next launch.

This is an OS-level process-lifecycle side effect — not unit-testable (there's no fake for `NSWorkspace` in this codebase, and adding one just to test a `Task { }` fire-and-forget call isn't worth the abstraction for a single call site). Build-verified here; behavior verified live in Task 10.

- [ ] **Step 1: Add the `relaunch()` method**

In `Sources/AgenticGlowApp/AppDelegate.swift`, add after `showSetupWindow()` (currently ends around line 295):

```swift
    private func relaunch() {
        UserDefaults.standard.set(true, forKey: "reopenSetupAfterRestart")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        Task {
            do {
                _ = try await NSWorkspace.shared.openApplication(
                    at: Bundle.main.bundleURL,
                    configuration: configuration
                )
                NSApp.terminate(nil)
            } catch {
                // Relaunch failed — stay running rather than leaving no
                // app at all. The flag would otherwise force-open Setup
                // on some unrelated future launch, so clear it too.
                UserDefaults.standard.removeObject(forKey: "reopenSetupAfterRestart")
            }
        }
    }
```

- [ ] **Step 2: Wire it into both Setup view models**

In `Sources/AgenticGlowApp/AppDelegate.swift`, change:

```swift
        let claudeModel = SetupViewModel(
            provider: .claude,
            executableURL: claudeExecutable,
            helperInstaller: helperInstaller,
            integration: claudeManager,
            syntheticEventService: syntheticEventService,
            lastEvent: { [weak model] in
                model?.resolved.sessions
                    .first { $0.provider == .claude }?.updatedAt
            },
            setIntegrationEnabled: {
                UserDefaults.standard.set($0, forKey: Self.integrationEnabledKey(for: .claude))
            }
        )

        let codexModel = SetupViewModel(
            provider: .codex,
            executableURL: codexExecutable,
            helperInstaller: helperInstaller,
            integration: codexManager,
            syntheticEventService: syntheticEventService,
            lastEvent: { [weak model] in
                model?.resolved.sessions
                    .first { $0.provider == .codex }?.updatedAt
            },
            setIntegrationEnabled: {
                UserDefaults.standard.set($0, forKey: Self.integrationEnabledKey(for: .codex))
            }
        )
```

to:

```swift
        let claudeModel = SetupViewModel(
            provider: .claude,
            executableURL: claudeExecutable,
            helperInstaller: helperInstaller,
            integration: claudeManager,
            syntheticEventService: syntheticEventService,
            lastEvent: { [weak model] in
                model?.resolved.sessions
                    .first { $0.provider == .claude }?.updatedAt
            },
            setIntegrationEnabled: {
                UserDefaults.standard.set($0, forKey: Self.integrationEnabledKey(for: .claude))
            },
            requestRestart: { [weak self] in self?.relaunch() }
        )

        let codexModel = SetupViewModel(
            provider: .codex,
            executableURL: codexExecutable,
            helperInstaller: helperInstaller,
            integration: codexManager,
            syntheticEventService: syntheticEventService,
            lastEvent: { [weak model] in
                model?.resolved.sessions
                    .first { $0.provider == .codex }?.updatedAt
            },
            setIntegrationEnabled: {
                UserDefaults.standard.set($0, forKey: Self.integrationEnabledKey(for: .codex))
            },
            requestRestart: { [weak self] in self?.relaunch() }
        )
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild build -project AgenticGlow.xcodeproj -scheme AgenticGlow CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Sources/AgenticGlowApp/AppDelegate.swift
git commit -m "feat: relaunch AgenticGlow after a successful Repair"
```

---

### Task 7: Reopen Setup after restart

**Files:**
- Modify: `Sources/AgenticGlowApp/AppDelegate.swift:194-199` (the Setup-opening conditional in `applicationDidFinishLaunching`)

**Interfaces:**
- Consumes: the `reopenSetupAfterRestart` `UserDefaults` flag set by `relaunch()` (Task 6).
- Produces: on the next launch, that flag (if present) is read and cleared exactly once, and forces `showSetupWindow()` regardless of the normal `completedSetup` gate.

- [ ] **Step 1: Read and consume the flag, and force Setup open when it was set**

In `Sources/AgenticGlowApp/AppDelegate.swift`, change:

```swift
        if fixtureName == "setup-repair" {
            showSetupWindow()
        } else if fixtureName == nil,
                  !UserDefaults.standard.bool(forKey: "completedSetup") {
            showSetupWindow()
        }
```

to:

```swift
        let shouldReopenSetupAfterRestart = fixtureName == nil
            && UserDefaults.standard.bool(forKey: "reopenSetupAfterRestart")
        if shouldReopenSetupAfterRestart {
            UserDefaults.standard.removeObject(forKey: "reopenSetupAfterRestart")
        }
        if fixtureName == "setup-repair" {
            showSetupWindow()
        } else if fixtureName == nil,
                  !UserDefaults.standard.bool(forKey: "completedSetup") || shouldReopenSetupAfterRestart {
            showSetupWindow()
        }
```

Note this always clears the flag on any real (non-fixture) launch, whether or not it was set, so it can never leak into a later unrelated session.

- [ ] **Step 2: Build to verify it compiles**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild build -project AgenticGlow.xcodeproj -scheme AgenticGlow CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Sources/AgenticGlowApp/AppDelegate.swift
git commit -m "feat: reopen Setup automatically after a restart"
```

---

### Task 8: Global Command+Shift+A hotkey

**Files:**
- Modify: `Sources/AgenticGlowApp/AppDelegate.swift` (new properties, registration/unregistration methods, handler; calls from `applicationDidFinishLaunching` and `applicationWillTerminate`)

**Interfaces:**
- Consumes: `StatusItemController.togglePopover()` (Task 5, now internal).
- Produces: a registered Command+Shift+A global hotkey while AgenticGlow runs (skipped under UI-test fixtures), cleanly unregistered on quit.

Carbon's `RegisterEventHotKey` claims the combo exclusively at the OS level — no Accessibility/Input Monitoring permission prompt, unlike an `NSEvent` global monitor. `import Carbon` is already present at the top of `AppDelegate.swift` (currently unused). Not unit-testable (no fake for the Carbon Event Manager); verified live in Task 10.

- [ ] **Step 1: Add the hotkey properties and registration/unregistration methods**

In `Sources/AgenticGlowApp/AppDelegate.swift`, add after `private let notificationClient = UserNotificationCenterClient()` (inside the `AppDelegate` class body):

```swift
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandlerRef: EventHandlerRef?
    private static let hotKeyID = EventHotKeyID(signature: OSType(0x41474C57), id: 1) // "AGLW"

    private func registerGlobalHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                delegate.handleGlobalHotKeyPressed()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &hotKeyEventHandlerRef
        )
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            UInt32(cmdKey | shiftKey),
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("AgenticGlow: failed to register the global Command+Shift+A hotkey (status \(status))")
        }
    }

    private func unregisterGlobalHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let hotKeyEventHandlerRef {
            RemoveEventHandler(hotKeyEventHandlerRef)
            self.hotKeyEventHandlerRef = nil
        }
    }

    private func handleGlobalHotKeyPressed() {
        statusItemController.togglePopover()
    }
```

- [ ] **Step 2: Register on launch, skipped for UI-test fixtures**

In `Sources/AgenticGlowApp/AppDelegate.swift`, change:

```swift
        reduceMotionObserver.start()
        usageAvailabilityObserver = UsageAvailabilityObserver(model: model)
        usageAvailabilityObserver.start()
        model.start()
```

to:

```swift
        reduceMotionObserver.start()
        usageAvailabilityObserver = UsageAvailabilityObserver(model: model)
        usageAvailabilityObserver.start()
        if fixtureName == nil {
            registerGlobalHotKey()
        }
        model.start()
```

- [ ] **Step 3: Unregister on quit**

In `Sources/AgenticGlowApp/AppDelegate.swift`, change:

```swift
    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        statusItemController.stop()
        reduceMotionObserver.stop()
        usageAvailabilityObserver.stop()
    }
```

to:

```swift
    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        statusItemController.stop()
        reduceMotionObserver.stop()
        usageAvailabilityObserver.stop()
        unregisterGlobalHotKey()
    }
```

- [ ] **Step 4: Build to verify it compiles**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild build -project AgenticGlow.xcodeproj -scheme AgenticGlow CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tail -30`

Expected: `** BUILD SUCCEEDED **`

If the closure literal passed to `InstallEventHandler` fails to type-check as a C function pointer (the most likely failure mode for this step — it happens if the closure ends up capturing something), the fix is to ensure the closure body references only its own three parameters and `AppDelegate` — nothing from the enclosing method's local scope.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgenticGlowApp/AppDelegate.swift
git commit -m "feat: add global Command+Shift+A hotkey to toggle the popover"
```

---

### Task 9: Full verification suite

**Files:** none (verification only)

- [ ] **Step 1: Clean derived data**

Run: `rm -rf /Users/jwright0180/Library/Developer/Xcode/DerivedData/AgenticGlow-*`

- [ ] **Step 2: Run the full non-UI test suite**

Run: `cd "/Volumes/Liquid/2DaMax Development/AgenticGlow" && xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES 2>&1 | tee /tmp/full_test_run_shortcut_restart.log | tail -80`

Expected: `AgenticGlowCoreTests` and `AgenticGlowAppTests` both pass with 0 failures (269 and 153 tests respectively — 147 from before this plan plus the 3 new `syncPhaseFromCurrentStatus` tests from Task 2 plus the 3 new restart tests from Task 4). `AgenticGlowUITests` may fail to bootstrap in a non-interactive session (a known local environment gap unrelated to this change, confirmed earlier this session) — that failure is not a regression to chase here, but if it fails with a *different* error than "crashed with signal kill before establishing connection," stop and investigate before proceeding.

- [ ] **Step 3: Confirm no unrelated diffs**

Run: `git status --short`

Expected: clean (everything already committed task-by-task).

---

### Task 10: Live manual verification

**Files:** none (verification only)

Neither the Carbon hotkey nor the actual process relaunch can be exercised by XCTest — they're OS-level side effects. Verify by hand, the same way this session verified the crash bisection.

- [ ] **Step 1: Build and install a fresh local copy**

Run:
```bash
pkill -x AgenticGlow 2>/dev/null; pkill -f AgenticGlowWidget 2>/dev/null; sleep 1
cd "/Volumes/Liquid/2DaMax Development/AgenticGlow"
rm -rf /tmp/agenticglow-shortcut-restart-build
xcodebuild -project AgenticGlow.xcodeproj -scheme AgenticGlow -configuration Debug -derivedDataPath /tmp/agenticglow-shortcut-restart-build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES build
rm -rf /Applications/AgenticGlow.app
cp -R /tmp/agenticglow-shortcut-restart-build/Build/Products/Debug/AgenticGlow.app /Applications/AgenticGlow.app
open /Applications/AgenticGlow.app
```

Expected: `** BUILD SUCCEEDED **`, app launches, menu bar icon appears.

- [ ] **Step 2: Verify the global hotkey**

Click into a different app (e.g. Terminal, Notes) so AgenticGlow is not frontmost. Press Command+Shift+A.

Expected: AgenticGlow's popover appears, without AgenticGlow becoming the frontmost app's window focus target in a disruptive way (matches existing `togglePopover()` behavior — it does call `NSApp.activate`, so some activation is expected). Press Command+Shift+A again with the popover open.

Expected: the popover closes.

- [ ] **Step 3: Verify Command+Shift+A does not collide with anything**

In a text field in another app (e.g. Notes, or a browser address bar), type some text, then press Command+Shift+A.

Expected: whatever Command+Shift+A normally does in that app happens (or nothing, if unbound there) — and separately, AgenticGlow's popover also toggles per Step 2. No system-wide text-editing behavior should be broken (this was the whole reason Control+A was rejected during brainstorming).

- [ ] **Step 4: Verify the Repair restart**

Open Setup (click the menu bar icon, then Settings/Integrations, however Setup is normally reached in the running build). Click "Repair" for Codex (or Claude — whichever is currently configured on this machine).

Expected: the row's status text changes to "Repair successful — restarting AgenticGlow…", then after roughly 1.5 seconds the menu bar icon disappears and reappears (the app relaunching), and the Setup window reopens automatically showing "Installed" or "Installed, trust required" for the repaired provider — not "Ready to install". (Revised after live testing: shipped behavior uses a 3s delay and replaces the whole row with a styled orange `Label`, not shared-row plain text.)

- [ ] **Step 5: Confirm no crash report was generated**

Run: `ls -la ~/Library/Logs/DiagnosticReports/ | grep -i agenticglow | tail -5`

Expected: no new `.ips` file with a timestamp after Step 4 was performed.

- [ ] **Step 6: Report results to John**

Summarize what was verified live (hotkey toggle, no text-field collision, restart message, actual relaunch, Setup reopening with correct state, no new crash report) so he can confirm before this ships in a release.
