# Client-Side Session Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user right-click a stale-looking session row (idle, disconnected, completed, or permission) and remove it from the popover without touching the underlying session file.

**Architecture:** `ResolutionMemory` gains an in-memory `hiddenRecords` dict keyed by `SessionKey`, storing the `eventUpdatedAt` present at the moment of hiding. `SessionResolver.resolve()` excludes any event whose hidden record still matches its current `updatedAt`, and clears the record (making the session reappear) the instant a newer event arrives. `AppModel.removeSession(_:)` is the only entry point that writes to this memory; it never calls `SessionStateStore.remove`. `SessionRowView` gains a `.contextMenu` with a "Remove" action, shown only for the four eligible phases.

**Tech Stack:** Swift 6, SwiftUI (macOS), XCTest.

## Global Constraints

- Removal never touches `SessionStateStore` or the on-disk JSON file — spec section "Mechanism".
- "Remove" is available only for `.idle`, `.disconnected`, `.completed`, `.permission` — spec section "Scope". `.thinking`/`.usingTool` rows get no context menu at all.
- A hidden session reappears silently (no special UI treatment) the moment a newer event supersedes its hidden record — spec section "Mechanism".
- No confirmation dialog on Remove — spec section "Interaction".
- Hides do not persist across an AgenticGlow relaunch — spec section "Mechanism".
- Context menu item: label "Remove", `systemImage: "xmark.circle"`, `role: .destructive` — spec section "Interaction".

---

### Task 1: Resolver-level hide/reveal

**Files:**
- Modify: `Sources/AgenticGlowCore/State/SessionSnapshot.swift`
- Modify: `Sources/AgenticGlowCore/State/SessionResolver.swift`
- Test: `Tests/AgenticGlowCoreTests/SessionResolverTests.swift`

**Interfaces:**
- Consumes: existing `SessionKey(provider:sessionID:)`, `SessionKey(_ event: NormalizedEvent)`, `ResolutionMemory` (both public, already defined in `SessionSnapshot.swift`).
- Produces: `public mutating func ResolutionMemory.hide(_ key: SessionKey, eventUpdatedAt: Date)`. Later tasks call this through `AppModel`.

- [ ] **Step 1: Write the failing tests**

Add to `Tests/AgenticGlowCoreTests/SessionResolverTests.swift`, directly above `func testUnknownProcessExpiresAfterFourHours()`:

```swift
    func testHiddenSessionIsExcludedFromResolvedSessions() {
        let ev = event(provider: .codex, session: "stale", phase: .permission, updated: 100)
        var memory = ResolutionMemory()
        memory.hide(
            SessionKey(provider: .codex, sessionID: "stale"),
            eventUpdatedAt: Date(timeIntervalSince1970: 100)
        )

        let resolved = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 105),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )

        XCTAssertTrue(resolved.sessions.isEmpty)
    }

    func testHiddenSessionReappearsWhenNewerEventArrives() {
        let key = SessionKey(provider: .codex, sessionID: "stale")
        var memory = ResolutionMemory()
        memory.hide(key, eventUpdatedAt: Date(timeIntervalSince1970: 100))

        let newerEvent = event(provider: .codex, session: "stale", phase: .thinking, updated: 200)
        let resolved = SessionResolver.resolve(
            events: [newerEvent],
            now: Date(timeIntervalSince1970: 205),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )

        XCTAssertEqual(resolved.sessions.first?.sessionID, "stale")
        XCTAssertEqual(resolved.sessions.first?.phase, .thinking)
    }

    func testHiddenRecordPrunedWhenKeyExpiresFromRetention() {
        let key = SessionKey(provider: .codex, sessionID: "stale")
        var memory = ResolutionMemory()
        memory.hide(key, eventUpdatedAt: Date(timeIntervalSince1970: 100))
        let ev = event(provider: .codex, session: "stale", phase: .permission, updated: 100)

        _ = SessionResolver.resolve(
            events: [ev],
            now: Date(timeIntervalSince1970: 100 + SessionResolver.fileRetention + 1),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )

        XCTAssertTrue(memory.hiddenRecords.isEmpty)
    }

```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowCoreTests/SessionResolverTests 2>&1 | tail -40`
Expected: build error — `value of type 'ResolutionMemory' has no member 'hide'` (and no `hiddenRecords` member). This is the TDD-red signal; a compile failure is expected here, not a runtime assertion failure.

- [ ] **Step 3: Implement `HiddenRecord` and `ResolutionMemory.hide`**

In `Sources/AgenticGlowCore/State/SessionSnapshot.swift`, replace:

```swift
struct DisconnectionRecord: Sendable {
    let eventUpdatedAt: Date
    let detectedAt: Date
}

public struct ResolutionMemory: Sendable {
    var disconnectedRecords: [SessionKey: DisconnectionRecord] = [:]

    public init() {}
}
```

with:

```swift
struct DisconnectionRecord: Sendable {
    let eventUpdatedAt: Date
    let detectedAt: Date
}

struct HiddenRecord: Sendable {
    let eventUpdatedAt: Date
}

public struct ResolutionMemory: Sendable {
    var disconnectedRecords: [SessionKey: DisconnectionRecord] = [:]
    var hiddenRecords: [SessionKey: HiddenRecord] = [:]

    public init() {}

    /// Records a client-side hide for `key`. The session stays excluded from
    /// resolved sessions until a newer event (a different `updatedAt`)
    /// arrives for the same key. Never touches the underlying session file.
    public mutating func hide(_ key: SessionKey, eventUpdatedAt: Date) {
        hiddenRecords[key] = HiddenRecord(eventUpdatedAt: eventUpdatedAt)
    }
}
```

- [ ] **Step 4: Wire the exclusion and pruning into `SessionResolver.resolve()`**

In `Sources/AgenticGlowCore/State/SessionResolver.swift`, replace:

```swift
        let retainedKeys = Set(events.compactMap { event in
            now.timeIntervalSince(event.updatedAt) <= fileRetention ? SessionKey(event) : nil
        })
        memory.disconnectedRecords = memory.disconnectedRecords.filter {
            retainedKeys.contains($0.key)
        }

        let snapshots = events.compactMap { event -> SessionSnapshot? in
            let age = now.timeIntervalSince(event.updatedAt)
            if age > fileRetention { return nil }

            let phase: SessionPhase
```

with:

```swift
        let retainedKeys = Set(events.compactMap { event in
            now.timeIntervalSince(event.updatedAt) <= fileRetention ? SessionKey(event) : nil
        })
        memory.disconnectedRecords = memory.disconnectedRecords.filter {
            retainedKeys.contains($0.key)
        }
        memory.hiddenRecords = memory.hiddenRecords.filter {
            retainedKeys.contains($0.key)
        }

        let snapshots = events.compactMap { event -> SessionSnapshot? in
            let age = now.timeIntervalSince(event.updatedAt)
            if age > fileRetention { return nil }

            if let hidden = memory.hiddenRecords[SessionKey(event)] {
                if hidden.eventUpdatedAt == event.updatedAt {
                    return nil
                }
                memory.hiddenRecords.removeValue(forKey: SessionKey(event))
            }

            let phase: SessionPhase
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowCoreTests/SessionResolverTests 2>&1 | tail -40`
Expected: `Executed 20 tests, with 0 failures`

- [ ] **Step 6: Run the full Core suite to confirm no regression**

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowCoreTests 2>&1 | tail -10`
Expected: `Executed 166 tests, with 0 failures` (163 existing + 3 new)

- [ ] **Step 7: Commit**

```bash
git add Sources/AgenticGlowCore/State/SessionSnapshot.swift Sources/AgenticGlowCore/State/SessionResolver.swift Tests/AgenticGlowCoreTests/SessionResolverTests.swift
git commit -m "$(cat <<'EOF'
feat: add client-side session hide to SessionResolver

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `AppModel.removeSession(_:)`

**Files:**
- Modify: `Sources/AgenticGlowApp/AppModel.swift`
- Test: `Tests/AgenticGlowAppTests/AppModelTests.swift`

**Interfaces:**
- Consumes: `ResolutionMemory.hide(_:eventUpdatedAt:)` from Task 1; `SessionSnapshot.provider`, `.sessionID`, `.updatedAt` (all existing public properties).
- Produces: `func AppModel.removeSession(_ session: SessionSnapshot)`. Task 3's `SessionListView` calls this.

- [ ] **Step 1: Write the failing test**

Add to `Tests/AgenticGlowAppTests/AppModelTests.swift`, directly above `func testRefreshReportsStoreLoadFailure()`:

```swift
    func testRemoveSessionHidesItFromResolvedSessions() {
        let store = InMemorySessionStore(events: [
            .testEvent(provider: .codex, phase: .permission, turnStartedAt: nil)
        ])
        let model = AppModel(
            store: store,
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            now: { Date(timeIntervalSince1970: 120) }
        )
        model.refresh()
        XCTAssertEqual(model.resolved.sessions.count, 1)
        let session = model.resolved.sessions[0]

        model.removeSession(session)

        XCTAssertTrue(model.resolved.sessions.isEmpty)
        XCTAssertEqual(store.events.count, 1, "removal must not touch the underlying session file")
    }

```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/AppModelTests/testRemoveSessionHidesItFromResolvedSessions 2>&1 | tail -30`
Expected: build error — `value of type 'AppModel' has no member 'removeSession'`

- [ ] **Step 3: Implement `removeSession`**

In `Sources/AgenticGlowApp/AppModel.swift`, replace:

```swift
    func activate(_ session: SessionSnapshot) {
        activator.activate(bundleIdentifier: session.sourceBundleID)
    }
```

with:

```swift
    func activate(_ session: SessionSnapshot) {
        activator.activate(bundleIdentifier: session.sourceBundleID)
    }

    func removeSession(_ session: SessionSnapshot) {
        resolutionMemory.hide(
            SessionKey(provider: session.provider, sessionID: session.sessionID),
            eventUpdatedAt: session.updatedAt
        )
        refresh()
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests/AppModelTests/testRemoveSessionHidesItFromResolvedSessions 2>&1 | tail -30`
Expected: `Executed 1 test, with 0 failures`

- [ ] **Step 5: Run the full App suite to confirm no regression**

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowAppTests 2>&1 | tail -10`
Expected: `Executed 85 tests, with 0 failures` (84 existing + 1 new)

- [ ] **Step 6: Commit**

```bash
git add Sources/AgenticGlowApp/AppModel.swift Tests/AgenticGlowAppTests/AppModelTests.swift
git commit -m "$(cat <<'EOF'
feat: add AppModel.removeSession for client-side hide

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Right-click "Remove" in the popover

**Files:**
- Modify: `Sources/AgenticGlowApp/MenuBar/SessionRowView.swift`
- Modify: `Sources/AgenticGlowApp/MenuBar/SessionListView.swift:126`

**Interfaces:**
- Consumes: `AppModel.removeSession(_:)` from Task 2.
- Produces: `SessionRowView(session:action:onRemove:)` (new three-argument initializer — the two-argument call site is being replaced in this task, so nothing later depends on the old signature).

No new automated test for this task — matches the existing convention that row-level icon/color/menu logic isn't unit-tested directly (only the pure static helpers `format`/`accessibilityLabel` are, and those are unchanged here). Verified manually in Task 4.

- [ ] **Step 1: Add `onRemove` and `isRemovable` to `SessionRowView`, gate the context menu**

Replace the full contents of `Sources/AgenticGlowApp/MenuBar/SessionRowView.swift` with:

```swift
import AgenticGlowCore
import SwiftUI

struct SessionRowView: View {
    let session: SessionSnapshot
    let action: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let row = Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.projectName)
                        .font(.body.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let elapsed = session.elapsedSeconds,
                   [.thinking, .usingTool].contains(session.phase) {
                    Text(Self.format(elapsed))
                        .monospacedDigit()
                        .font(.caption)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("AgenticGlow.Session.\(session.id)")
        .accessibilityLabel(Self.accessibilityLabel(for: session))
        .accessibilityHint("Activates the source application")

        if isRemovable {
            row.contextMenu {
                Button("Remove", systemImage: "xmark.circle", role: .destructive, action: onRemove)
            }
        } else {
            row
        }
    }

    private var isRemovable: Bool {
        [.idle, .disconnected, .completed, .permission].contains(session.phase)
    }

    private var detail: String {
        "\(session.label) · \(session.surface.displayName)"
    }

    private var icon: String {
        switch session.phase {
        case .permission: "exclamationmark.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .disconnected: "bolt.slash.circle"
        case .idle: "circle"
        case .thinking, .usingTool: "sparkle"
        }
    }

    private var color: Color {
        switch session.phase {
        case .permission: Color(nsColor: .systemYellow)
        case .completed: Color(nsColor: .systemGreen)
        case .disconnected: .secondary
        case .idle: .primary
        case .thinking, .usingTool: ProviderColor.color(for: session.provider)
        }
    }

    static func accessibilityLabel(for session: SessionSnapshot) -> String {
        "\(session.provider.displayName), \(session.projectName), \(session.label), \(session.surface.displayName)"
    }

    /// Seconds drop out at the hour scale so long-running rows stay calm.
    static func format(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3_600 { return "\(seconds / 60)m \(seconds % 60)s" }
        let minutes = (seconds % 3_600) / 60
        return minutes == 0 ? "\(seconds / 3_600)h" : "\(seconds / 3_600)h \(minutes)m"
    }
}

private extension AgentProvider {
    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        }
    }
}

private extension SourceSurface {
    var displayName: String {
        switch self {
        case .cli: "CLI"
        case .desktop: "Desktop"
        case .unknown: "Unknown source"
        }
    }
}
```

- [ ] **Step 2: Wire the new parameter at the call site**

In `Sources/AgenticGlowApp/MenuBar/SessionListView.swift`, replace:

```swift
                    ForEach(model.resolved.sessions) { session in
                        SessionRowView(session: session) { model.activate(session) }
                    }
```

with:

```swift
                    ForEach(model.resolved.sessions) { session in
                        SessionRowView(
                            session: session,
                            action: { model.activate(session) },
                            onRemove: { model.removeSession(session) }
                        )
                    }
```

- [ ] **Step 3: Build to confirm it compiles**

Run: `xcodebuild build -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the full non-UI suite to confirm no regression**

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowCoreTests -only-testing:AgenticGlowAppTests 2>&1 | tail -10`
Expected: `Executed 85 tests, with 0 failures` for AgenticGlowAppTests and `Executed 166 tests, with 0 failures` for AgenticGlowCoreTests (matches Task 1/2 counts — this task adds no new tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/AgenticGlowApp/MenuBar/SessionRowView.swift Sources/AgenticGlowApp/MenuBar/SessionListView.swift
git commit -m "$(cat <<'EOF'
feat: add right-click Remove to stale session rows

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Live verification and docs

**Files:**
- Modify: `gotdone.md`

**Interfaces:**
- Consumes: the fully wired feature from Tasks 1–3.
- Produces: nothing new — this task only verifies and records evidence.

- [ ] **Step 1: Launch the app against the built-in `signals` UI-test fixture**

This fixture (`Sources/AgenticGlowApp/UITesting/UITestSessionStore.swift`) preloads exactly one `.permission` Claude session ("Example") and one `.thinking` Codex session ("AgenticGlow") without touching real session files — ideal for exercising both the removable and non-removable code paths in one launch.

Run:
```bash
xcodebuild build -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' 2>&1 | tail -5
open --new -a "$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -iname 'AgenticGlow-*' | head -1)/Build/Products/Debug/AgenticGlow.app" --args --ui-test-fixture signals
```

- [ ] **Step 2: Right-click the permission row and confirm Remove clears it**

Click the menu bar item to open the popover. Right-click the "Example" row (Claude, "Awaiting permission"). Confirm a single red "Remove" item appears. Click it. Confirm the row disappears immediately and the popover now shows only the "AgenticGlow" (Codex, Thinking) row. Take a screenshot for the record (same `screencapture`/accessibility-click technique used for the v0.4.10 verification in this session).

- [ ] **Step 3: Right-click the thinking row and confirm no menu appears**

Right-click the remaining "AgenticGlow" (Codex, Thinking) row. Confirm no context menu appears at all (not an empty menu — nothing).

- [ ] **Step 4: Quit the fixture-launched instance**

```bash
pkill -f "AgenticGlow.app/Contents/MacOS/AgenticGlow" || true
```

- [ ] **Step 5: Run the complete non-UI suite one more time**

Run: `xcodebuild test -project AgenticGlow.xcodeproj -scheme AgenticGlow -destination 'platform=macOS' -only-testing:AgenticGlowCoreTests -only-testing:AgenticGlowAppTests 2>&1 | tail -10`
Expected: zero failures across both targets.

- [ ] **Step 6: Record the work in `gotdone.md`**

Append a new dated section following the file's existing format (see the most recent entries for the exact style), covering: what was built, the test counts, and the live verification result from Steps 2–3.

- [ ] **Step 7: Commit**

```bash
git add gotdone.md
git commit -m "$(cat <<'EOF'
docs: record client-side session removal feature

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

Do not push. Confirm with the user before pushing, matching how prior work in this project has been handled (push only on explicit request).
