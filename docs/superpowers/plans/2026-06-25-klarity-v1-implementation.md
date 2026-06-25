# Klarity v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a free, local-only macOS menu bar app that reports live Codex and Claude session status through safe user-level hooks.

**Architecture:** Generate a native Xcode project from `project.yml`. Keep provider payload parsing, normalized session state, configuration merging, process inspection, and update logic in a testable `KlarityCore` framework. Ship a small native `klarity-event` command-line helper inside the app, copy it to a stable Application Support path during setup, and let the menu bar app poll atomic per-session JSON files without a daemon.

**Tech Stack:** Swift 6.0, SwiftUI, AppKit, Observation, ServiceManagement, XCTest, XCUITest, XcodeGen 2.45+, Xcode 26.5+, macOS 14+, shell release scripts, GitHub Releases, and Homebrew Cask.

## Global Constraints

- Product working name: `Klarity`.
- Public release remains blocked until trademark, marketplace, GitHub, Homebrew token, domain, and handle clearance is explicitly recorded.
- Minimum platform: macOS 14.0.
- Architectures: arm64 and x86_64.
- Supported sources: Codex CLI, Codex Desktop, Claude Code CLI, and Claude Desktop Code.
- No accounts, backend, analytics, telemetry, uploaded crash reports, prompt storage, response storage, command storage, tool-argument storage, or remote monitoring.
- Network access is limited to manual update checks or an explicitly enabled automatic GitHub release check.
- Automatic update checks default to off.
- No runtime dependency on Node.js, Python, Homebrew, or a background daemon.
- Klarity may activate the correct source application, but must not claim exact terminal-tab or agent-thread navigation unless a stable supported mechanism exists.
- Installation, repair, and removal must preserve unrelated Codex and Claude configuration.
- Codex hook trust must never be bypassed.
- Use Test-Driven Development for behavioral code.
- Make surgical commits. One task equals one reviewable commit.
- Do not publish a GitHub repository, release, Cask, website, or package without explicit user approval.

---

## File Map

### Project generation and configuration

- `project.yml`: Source of truth for Xcode targets, schemes, deployment target, resources, tests, and helper embedding.
- `Config/Klarity-Info.plist`: App metadata, menu bar-only activation policy, version, and bundle identifier.
- `Config/Klarity.entitlements`: Hardened runtime entitlement file with no App Sandbox entitlement.
- `Config/Debug.xcconfig`: Local debug defaults.
- `Config/Release.xcconfig`: Release build defaults.

### Shared core

- `Sources/KlarityCore/Product/ProductMetadata.swift`: Stable product constants.
- `Sources/KlarityCore/Events/AgentProvider.swift`: Provider and source-surface enums.
- `Sources/KlarityCore/Events/NormalizedEvent.swift`: Versioned local event schema and validation.
- `Sources/KlarityCore/Events/HookEventKind.swift`: Supported provider lifecycle event names.
- `Sources/KlarityCore/Events/ToolCategory.swift`: Safe tool-name to display-label mapping.
- `Sources/KlarityCore/Events/HookNormalizer.swift`: Claude and Codex payload normalization without persisting prohibited content.
- `Sources/KlarityCore/State/SessionKey.swift`: Stable provider and session identity plus safe filename generation.
- `Sources/KlarityCore/State/SessionStateStore.swift`: Atomic per-session JSON persistence and loading.
- `Sources/KlarityCore/State/SessionSnapshot.swift`: Display-ready session state.
- `Sources/KlarityCore/State/SessionResolver.swift`: Priority, sorting, completion duration, disconnection, and expiration rules.
- `Sources/KlarityCore/Processes/ProcessIdentity.swift`: Process identity and source-app metadata.
- `Sources/KlarityCore/Processes/ProcessInspector.swift`: Darwin process inspection boundary.
- `Sources/KlarityCore/Processes/ProcessIdentityResolver.swift`: Provider ancestor and source bundle detection.
- `Sources/KlarityCore/Processes/SourceApplicationActivator.swift`: Best-effort activation of the correct app.
- `Sources/KlarityCore/Integrations/HookDefinitionFactory.swift`: Exact Klarity hook entries for Claude and Codex.
- `Sources/KlarityCore/Integrations/JSONConfigEditor.swift`: Validated backup, merge, atomic write, and ownership checks.
- `Sources/KlarityCore/Integrations/ClaudeIntegrationManager.swift`: Claude settings install, diagnosis, repair, and removal.
- `Sources/KlarityCore/Integrations/CodexIntegrationManager.swift`: Codex hooks install, diagnosis, repair, removal, and trust instructions.
- `Sources/KlarityCore/Integrations/HelperInstaller.swift`: Copies and verifies the embedded helper at its stable path.
- `Sources/KlarityCore/Updates/UpdateChecker.swift`: Opt-in GitHub release check.
- `Sources/KlarityCore/Logging/DiagnosticLogger.swift`: Disabled-by-default sanitized local diagnostics.

### Event helper

- `Sources/KlarityCore/Helper/KlarityEventCommand.swift`: Testable CLI orchestration shared with the helper target.
- `Sources/KlarityEvent/main.swift`: Reads arguments and standard input, then exits with a stable code.

### App

- `Sources/KlarityApp/KlarityApp.swift`: SwiftUI app entry point.
- `Sources/KlarityApp/AppDelegate.swift`: Menu bar lifecycle and settings-window coordination.
- `Sources/KlarityApp/AppModel.swift`: Main-actor observable state and 0.5-second refresh loop.
- `Sources/KlarityApp/MenuBar/StatusItemController.swift`: `NSStatusItem`, popover, title, animation, and accessibility.
- `Sources/KlarityApp/MenuBar/StatusPresentation.swift`: Pure mapping from resolved state to icon, label, count, and color.
- `Sources/KlarityApp/MenuBar/SessionListView.swift`: Provider-grouped session list and footer actions.
- `Sources/KlarityApp/MenuBar/SessionRowView.swift`: Project, source, status, and elapsed time.
- `Sources/KlarityApp/Setup/SetupView.swift`: First-launch privacy explanation and integration setup.
- `Sources/KlarityApp/Setup/SetupViewModel.swift`: Detection, install, synthetic test, trust, and repair state.
- `Sources/KlarityApp/Settings/SettingsView.swift`: Timer, animation, launch-at-login, updates, and integrations.
- `Sources/KlarityApp/Services/LaunchAtLoginService.swift`: `SMAppService.mainApp` wrapper.
- `Sources/KlarityApp/Services/SyntheticEventService.swift`: Local setup verification through the installed helper.
- `Sources/KlarityApp/Resources/Assets.xcassets`: App icon and color assets.

### Tests and fixtures

- `Tests/KlarityCoreTests/`: Unit tests for schema, normalization, state, process logic, configuration, updates, and logging.
- `Tests/KlarityEventTests/`: Command orchestration tests using temporary directories and injected dependencies.
- `Tests/KlarityAppTests/`: App-model and presentation tests.
- `Tests/KlarityUITests/`: First launch, setup, menu bar, permission, multi-session, repair, and accessibility smoke tests.
- `Tests/TestSupport/TestSupport.swift`: Shared temporary-directory helpers for unit-test targets.
- `Tests/Fixtures/claude/`: Sanitized Claude hook payloads.
- `Tests/Fixtures/codex/`: Sanitized Codex hook payloads.

### Documentation and release tooling

- `README.md`: Product summary, installation, privacy, compatibility, contribution, and attribution.
- `LICENSE`: MIT license.
- `docs/privacy.md`: Exact local fields and network behavior.
- `docs/integrations.md`: Hook behavior, trust, repair, and removal.
- `docs/release-checklist.md`: Naming, signing, notarization, accessibility, and distribution gates.
- `Design/KlarityIcon-1024.png`: Approved source icon.
- `Scripts/build-release.sh`: Universal Release build and app assembly.
- `Scripts/create-dmg.sh`: Signed DMG creation.
- `Scripts/verify-release.sh`: Architecture, signature, Gatekeeper, notarization, and privacy checks.
- `Scripts/generate-cask.sh`: Produces a versioned Cask with the real DMG SHA-256.
- `Cask/klarity.rb`: Generated Homebrew Cask for the current release.
- `.github/workflows/ci.yml`: Build and test on macOS.
- `.github/workflows/release.yml`: Manual signed release workflow, inactive until secrets and publication approval exist.

---

### Task 1: Generate the Xcode project and prove all targets build

**Files:**
- Create: `project.yml`
- Create: `Config/Klarity-Info.plist`
- Create: `Config/Klarity.entitlements`
- Create: `Config/Debug.xcconfig`
- Create: `Config/Release.xcconfig`
- Create: `Sources/KlarityCore/Product/ProductMetadata.swift`
- Create: `Sources/KlarityEvent/main.swift`
- Create: `Sources/KlarityApp/KlarityApp.swift`
- Create: `Sources/KlarityApp/AppDelegate.swift`
- Create: `Sources/KlarityApp/Resources/Assets.xcassets/Contents.json`
- Create: `Tests/KlarityCoreTests/ProductMetadataTests.swift`
- Create: `Tests/KlarityEventTests/KlarityEventSmokeTests.swift`
- Create: `Tests/KlarityAppTests/KlarityAppSmokeTests.swift`
- Create: `Tests/KlarityUITests/KlarityLaunchTests.swift`
- Create: `Tests/TestSupport/TestSupport.swift`

**Interfaces:**
- Produces: `ProductMetadata.displayName`, `ProductMetadata.bundleIdentifier`, `ProductMetadata.schemaVersion`, and generated schemes `Klarity`, `KlarityEvent`, and `KlarityCore`.
- Consumes: Nothing.

- [ ] **Step 1: Add the project specification and minimal target files**

```yaml
# project.yml
name: Klarity
options:
  createIntermediateGroups: true
  bundleIdPrefix: com.twodamax
configs:
  Debug: debug
  Release: release
configFiles:
  Debug: Config/Debug.xcconfig
  Release: Config/Release.xcconfig
settings:
  base:
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    SWIFT_VERSION: "6.0"
    CLANG_ENABLE_MODULES: YES
    ONLY_ACTIVE_ARCH: NO
targets:
  KlarityCore:
    type: framework
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - Sources/KlarityCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.twodamax.klarity.core
        DEFINES_MODULE: YES
  KlarityEvent:
    type: tool
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - Sources/KlarityEvent
    dependencies:
      - target: KlarityCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.twodamax.klarity.event
        PRODUCT_NAME: klarity-event
  Klarity:
    type: application
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - Sources/KlarityApp
    resources:
      - Sources/KlarityApp/Resources
    info:
      path: Config/Klarity-Info.plist
    entitlements:
      path: Config/Klarity.entitlements
    dependencies:
      - target: KlarityCore
      - target: KlarityEvent
        embed: false
    postBuildScripts:
      - name: Embed Klarity event helper
        basedOnDependencyAnalysis: false
        script: |
          set -euo pipefail
          destination="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/bin"
          mkdir -p "$destination"
          cp "$BUILT_PRODUCTS_DIR/klarity-event" "$destination/klarity-event"
          chmod 755 "$destination/klarity-event"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.twodamax.klarity
        PRODUCT_NAME: Klarity
        GENERATE_INFOPLIST_FILE: NO
  KlarityCoreTests:
    type: bundle.unit-test
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - Tests/KlarityCoreTests
      - Tests/TestSupport
      - Tests/Fixtures
    dependencies:
      - target: KlarityCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.twodamax.klarity.core-tests
  KlarityEventTests:
    type: bundle.unit-test
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - Tests/KlarityEventTests
      - Tests/TestSupport
      - Tests/Fixtures
    dependencies:
      - target: KlarityCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.twodamax.klarity.event-tests
  KlarityAppTests:
    type: bundle.unit-test
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - Tests/KlarityAppTests
      - Tests/TestSupport
    dependencies:
      - target: Klarity
      - target: KlarityCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.twodamax.klarity.app-tests
  KlarityUITests:
    type: bundle.ui-testing
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - Tests/KlarityUITests
    dependencies:
      - target: Klarity
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.twodamax.klarity.ui-tests
schemes:
  Klarity:
    build:
      targets:
        Klarity: all
        KlarityCoreTests: [test]
        KlarityEventTests: [test]
        KlarityAppTests: [test]
        KlarityUITests: [test]
    test:
      targets:
        - KlarityCoreTests
        - KlarityEventTests
        - KlarityAppTests
        - KlarityUITests
  KlarityEvent:
    build:
      targets:
        KlarityEvent: all
        KlarityEventTests: [test]
    test:
      targets:
        - KlarityEventTests
```

```swift
// Sources/KlarityCore/Product/ProductMetadata.swift
import Foundation

public enum ProductMetadata {
    public static let displayName = "Klarity"
    public static let bundleIdentifier = "com.twodamax.klarity"
    public static let helperName = "klarity-event"
    public static let schemaVersion = 1
}
```

```swift
// Sources/KlarityEvent/main.swift
import Foundation
import KlarityCore

FileHandle.standardError.write(Data("klarity-event is not configured yet\n".utf8))
exit(64)
```

```swift
// Sources/KlarityApp/KlarityApp.swift
import SwiftUI

@main
struct KlarityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Klarity")
                .padding()
        }
    }
}
```

```swift
// Sources/KlarityApp/AppDelegate.swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

```json
// Sources/KlarityApp/Resources/Assets.xcassets/Contents.json
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

- [ ] **Step 2: Add failing metadata tests**

```swift
// Tests/KlarityCoreTests/ProductMetadataTests.swift
import XCTest
@testable import KlarityCore

final class ProductMetadataTests: XCTestCase {
    func testProductConstantsMatchPublicIdentifiers() {
        XCTAssertEqual(ProductMetadata.displayName, "Klarity")
        XCTAssertEqual(ProductMetadata.bundleIdentifier, "com.twodamax.klarity")
        XCTAssertEqual(ProductMetadata.schemaVersion, 1)
    }
}
```

```swift
// Tests/KlarityEventTests/KlarityEventSmokeTests.swift
import XCTest
@testable import KlarityCore

final class KlarityEventSmokeTests: XCTestCase {
    func testHelperNameIsStable() {
        XCTAssertEqual(ProductMetadata.helperName, "klarity-event")
    }
}
```

```swift
// Tests/KlarityAppTests/KlarityAppSmokeTests.swift
import XCTest
@testable import KlarityCore

final class KlarityAppSmokeTests: XCTestCase {
    func testAppBundleIdentifierIsStable() {
        XCTAssertEqual(ProductMetadata.bundleIdentifier, "com.twodamax.klarity")
    }
}
```

```swift
// Tests/KlarityUITests/KlarityLaunchTests.swift
import XCTest

final class KlarityLaunchTests: XCTestCase {
    func testApplicationLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5)
            || app.wait(for: .runningBackground, timeout: 5))
    }
}
```

```swift
// Tests/TestSupport/TestSupport.swift
import Foundation

func temporaryDirectory(
    file: StaticString = #filePath,
    line: UInt = #line
) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("KlarityTests-\(UUID().uuidString)", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    } catch {
        fatalError("Could not create temporary directory at \(file):\(line): \(error)")
    }
}
```

- [ ] **Step 3: Add plist, entitlement, and xcconfig content**

```xml
<!-- Config/Klarity-Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key><string>Klarity</string>
  <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key><string>$(CURRENT_PROJECT_VERSION)</string>
  <key>LSMinimumSystemVersion</key><string>$(MACOSX_DEPLOYMENT_TARGET)</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Klarity contributors</string>
</dict>
</plist>
```

```xml
<!-- Config/Klarity.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
```

```text
// Config/Debug.xcconfig
MARKETING_VERSION = 0.1.0
CURRENT_PROJECT_VERSION = 1
CODE_SIGN_STYLE = Automatic
ENABLE_HARDENED_RUNTIME = YES
```

```text
// Config/Release.xcconfig
MARKETING_VERSION = 0.1.0
CURRENT_PROJECT_VERSION = 1
CODE_SIGN_STYLE = Manual
ENABLE_HARDENED_RUNTIME = YES
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
```

- [ ] **Step 4: Generate the project and run tests**

Run:

```bash
xcodegen generate
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: project generation succeeds and all four smoke-test bundles pass.

- [ ] **Step 5: Verify the helper is embedded**

Run:

```bash
xcodebuild build \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
test -x "$HOME/Library/Developer/Xcode/DerivedData/Klarity-"*/Build/Products/Debug/Klarity.app/Contents/Resources/bin/klarity-event
```

Expected: the final `test -x` exits `0`.

- [ ] **Step 6: Commit**

```bash
git add project.yml Config Sources Tests Klarity.xcodeproj
git commit -m "build: scaffold Klarity macOS targets"
```

---

### Task 2: Define and validate the normalized event schema

**Files:**
- Create: `Sources/KlarityCore/Events/AgentProvider.swift`
- Create: `Sources/KlarityCore/Events/HookEventKind.swift`
- Create: `Sources/KlarityCore/Events/ToolCategory.swift`
- Create: `Sources/KlarityCore/Events/NormalizedEvent.swift`
- Create: `Tests/KlarityCoreTests/NormalizedEventTests.swift`

**Interfaces:**
- Produces: `AgentProvider`, `SourceSurface`, `SessionPhase`, `HookEventKind`, `ToolCategory`, `NormalizedEvent`, `NormalizedEvent.validate()`, `JSONEncoder.klarity`, and `JSONDecoder.klarity`.
- Consumes: `ProductMetadata.schemaVersion`.

- [ ] **Step 1: Write failing schema tests**

```swift
// Tests/KlarityCoreTests/NormalizedEventTests.swift
import XCTest
@testable import KlarityCore

final class NormalizedEventTests: XCTestCase {
    func testRoundTripUsesSecondsSince1970() throws {
        let event = NormalizedEvent.fixture()
        let data = try JSONEncoder.klarity.encode(event)
        let decoded = try JSONDecoder.klarity.decode(NormalizedEvent.self, from: data)
        XCTAssertEqual(decoded, event)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("prompt"))
    }

    func testValidationRejectsUnsupportedSchema() {
        var event = NormalizedEvent.fixture()
        event.schemaVersion = 99
        XCTAssertThrowsError(try event.validate()) { error in
            XCTAssertEqual(error as? EventValidationError, .unsupportedSchema(99))
        }
    }

    func testValidationRejectsUnsafeSessionIdentifier() {
        var event = NormalizedEvent.fixture()
        event.sessionID = "../escape"
        XCTAssertThrowsError(try event.validate())
    }
}

private extension NormalizedEvent {
    static func fixture() -> Self {
        .init(
            schemaVersion: 1,
            provider: .codex,
            surface: .cli,
            sessionID: "session-1",
            turnID: "turn-1",
            phase: .thinking,
            label: "Thinking",
            toolCategory: nil,
            projectName: "Klarity",
            workingDirectory: "/tmp/Klarity",
            sourceBundleID: "com.apple.Terminal",
            sourceProcessID: 123,
            sourceProcessStartedAt: Date(timeIntervalSince1970: 100),
            turnStartedAt: Date(timeIntervalSince1970: 110),
            updatedAt: Date(timeIntervalSince1970: 120)
        )
    }
}
```

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/NormalizedEventTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `NormalizedEvent` and its related types do not exist.

- [ ] **Step 3: Add the schema types**

```swift
// Sources/KlarityCore/Events/AgentProvider.swift
import Foundation

public enum AgentProvider: String, Codable, CaseIterable, Sendable {
    case codex
    case claude
}

public enum SourceSurface: String, Codable, Sendable {
    case cli
    case desktop
    case unknown
}

public enum SessionPhase: String, Codable, Sendable {
    case idle
    case thinking
    case usingTool
    case permission
    case completed
    case disconnected
}
```

```swift
// Sources/KlarityCore/Events/HookEventKind.swift
import Foundation

public enum HookEventKind: String, CaseIterable, Sendable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case notification = "Notification"
    case permissionRequest = "PermissionRequest"
    case stop = "Stop"
}
```

```swift
// Sources/KlarityCore/Events/ToolCategory.swift
import Foundation

public enum ToolCategory: String, Codable, Sendable {
    case read
    case edit
    case search
    case browse
    case command
    case delegate
    case other

    public static func classify(_ toolName: String) -> Self {
        switch toolName {
        case "Read": .read
        case "Edit", "Write", "MultiEdit", "apply_patch": .edit
        case "Grep", "Glob", "find", "rg": .search
        case "WebFetch", "WebSearch", "web_search": .browse
        case "Bash", "exec_command", "write_stdin": .command
        case "Task", "spawn_agent": .delegate
        default: .other
        }
    }

    public var label: String {
        switch self {
        case .read: "Reading"
        case .edit: "Editing"
        case .search: "Searching"
        case .browse: "Browsing"
        case .command: "Running command"
        case .delegate: "Delegating"
        case .other: "Using tool"
        }
    }
}
```

```swift
// Sources/KlarityCore/Events/NormalizedEvent.swift
import Foundation

public enum EventValidationError: Error, Equatable {
    case unsupportedSchema(Int)
    case invalidSessionID
    case invalidProjectName
    case invalidWorkingDirectory
}

public struct NormalizedEvent: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public let provider: AgentProvider
    public let surface: SourceSurface
    public var sessionID: String
    public let turnID: String?
    public let phase: SessionPhase
    public let label: String
    public let toolCategory: ToolCategory?
    public let projectName: String
    public let workingDirectory: String
    public let sourceBundleID: String?
    public let sourceProcessID: Int32?
    public let sourceProcessStartedAt: Date?
    public let turnStartedAt: Date?
    public let updatedAt: Date

    public init(
        schemaVersion: Int,
        provider: AgentProvider,
        surface: SourceSurface,
        sessionID: String,
        turnID: String?,
        phase: SessionPhase,
        label: String,
        toolCategory: ToolCategory?,
        projectName: String,
        workingDirectory: String,
        sourceBundleID: String?,
        sourceProcessID: Int32?,
        sourceProcessStartedAt: Date?,
        turnStartedAt: Date?,
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.provider = provider
        self.surface = surface
        self.sessionID = sessionID
        self.turnID = turnID
        self.phase = phase
        self.label = label
        self.toolCategory = toolCategory
        self.projectName = projectName
        self.workingDirectory = workingDirectory
        self.sourceBundleID = sourceBundleID
        self.sourceProcessID = sourceProcessID
        self.sourceProcessStartedAt = sourceProcessStartedAt
        self.turnStartedAt = turnStartedAt
        self.updatedAt = updatedAt
    }

    public func validate() throws {
        guard schemaVersion == ProductMetadata.schemaVersion else {
            throw EventValidationError.unsupportedSchema(schemaVersion)
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !sessionID.isEmpty,
              sessionID.count <= 128,
              sessionID.unicodeScalars.allSatisfy(allowed.contains) else {
            throw EventValidationError.invalidSessionID
        }
        guard !projectName.contains("\n"), projectName.count <= 128 else {
            throw EventValidationError.invalidProjectName
        }
        guard workingDirectory.hasPrefix("/"), !workingDirectory.contains("\0") else {
            throw EventValidationError.invalidWorkingDirectory
        }
    }
}

public extension JSONEncoder {
    static var klarity: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var klarity: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
```

- [ ] **Step 4: Run the focused tests**

Run the command from Step 2.

Expected: `NormalizedEventTests` PASS.

- [ ] **Step 5: Run all unit tests and commit**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -skip-testing:KlarityUITests \
  CODE_SIGNING_ALLOWED=NO
git add Sources/KlarityCore/Events Tests/KlarityCoreTests/NormalizedEventTests.swift
git commit -m "feat: define normalized event schema"
```

Expected: all non-UI tests PASS, then the commit succeeds.

---

### Task 3: Normalize Claude and Codex hook payloads without leaking content

**Files:**
- Create: `Sources/KlarityCore/Events/HookNormalizer.swift`
- Create: `Tests/KlarityCoreTests/HookNormalizerTests.swift`
- Create: `Tests/Fixtures/claude/user-prompt-submit.json`
- Create: `Tests/Fixtures/claude/permission-request.json`
- Create: `Tests/Fixtures/codex/pre-tool-use.json`
- Create: `Tests/Fixtures/codex/stop.json`

**Interfaces:**
- Produces: `HookNormalizer.normalize(provider:event:payload:environment:processIdentity:previous:now:) throws -> NormalizedEvent?`.
- Consumes: `AgentProvider`, `HookEventKind`, `ToolCategory`, `NormalizedEvent`, and `ProcessIdentity`.

- [ ] **Step 1: Add sanitized fixtures containing prohibited decoy content**

```json
// Tests/Fixtures/claude/user-prompt-submit.json
{
  "session_id": "claude-session",
  "cwd": "/tmp/Example",
  "prompt": "SECRET_PROMPT_MUST_NOT_PERSIST",
  "permission_mode": "default"
}
```

```json
// Tests/Fixtures/claude/permission-request.json
{
  "session_id": "claude-session",
  "cwd": "/tmp/Example",
  "tool_name": "Bash",
  "tool_input": {"command": "SECRET_COMMAND_MUST_NOT_PERSIST"}
}
```

```json
// Tests/Fixtures/codex/pre-tool-use.json
{
  "session_id": "codex-session",
  "turn_id": "turn-2",
  "cwd": "/tmp/Klarity",
  "hook_event_name": "PreToolUse",
  "tool_name": "apply_patch",
  "tool_input": {"patch": "SECRET_PATCH_MUST_NOT_PERSIST"}
}
```

```json
// Tests/Fixtures/codex/stop.json
{
  "session_id": "codex-session",
  "turn_id": "turn-2",
  "cwd": "/tmp/Klarity",
  "hook_event_name": "Stop",
  "last_assistant_message": "SECRET_RESPONSE_MUST_NOT_PERSIST"
}
```

- [ ] **Step 2: Write failing normalization and privacy tests**

```swift
// Tests/KlarityCoreTests/HookNormalizerTests.swift
import XCTest
@testable import KlarityCore

final class HookNormalizerTests: XCTestCase {
    func testClaudePromptStartsThinkingTimerWithoutPersistingPrompt() throws {
        let payload = try fixture("claude/user-prompt-submit")
        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .claude,
            event: .userPromptSubmit,
            payload: payload,
            environment: ["TERM_PROGRAM": "Apple_Terminal", "__CFBundleIdentifier": "com.apple.Terminal"],
            processIdentity: .fixture,
            previous: nil,
            now: Date(timeIntervalSince1970: 500)
        ))

        XCTAssertEqual(event.phase, .thinking)
        XCTAssertEqual(event.turnStartedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(event.surface, .cli)
        XCTAssertEqual(event.sourceBundleID, "com.apple.Terminal")
        let encoded = try JSONEncoder.klarity.encode(event)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("SECRET_PROMPT"))
    }

    func testCodexPreToolUseMapsApplyPatchToEditingAndPreservesTimer() throws {
        let previous = NormalizedEvent.testEvent(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 400)
        )
        let event = try XCTUnwrap(HookNormalizer.normalize(
            provider: .codex,
            event: .preToolUse,
            payload: try fixture("codex/pre-tool-use"),
            environment: [:],
            processIdentity: .fixture,
            previous: previous,
            now: Date(timeIntervalSince1970: 501)
        ))

        XCTAssertEqual(event.phase, .usingTool)
        XCTAssertEqual(event.toolCategory, .edit)
        XCTAssertEqual(event.label, "Editing")
        XCTAssertEqual(event.turnStartedAt, Date(timeIntervalSince1970: 400))
        let encoded = try JSONEncoder.klarity.encode(event)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("SECRET_PATCH"))
    }

    func testNonPermissionNotificationIsIgnored() throws {
        let payload: [String: Any] = [
            "session_id": "claude-session",
            "cwd": "/tmp/Example",
            "notification_type": "idle_prompt",
            "message": "Waiting for input"
        ]
        XCTAssertNil(try HookNormalizer.normalize(
            provider: .claude,
            event: .notification,
            payload: payload,
            environment: [:],
            processIdentity: nil,
            previous: nil,
            now: Date()
        ))
    }

    private func fixture(_ name: String) throws -> [String: Any] {
        let parts = name.split(separator: "/", maxSplits: 1).map(String.init)
        let url = Bundle(for: Self.self).url(
            forResource: parts[1],
            withExtension: "json",
            subdirectory: parts[0]
        )!
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
    }
}
```

- [ ] **Step 3: Run the focused test and verify failure**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HookNormalizerTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `HookNormalizer` and `ProcessIdentity.fixture` do not exist.

- [ ] **Step 4: Add the minimal process identity model**

```swift
// Sources/KlarityCore/Processes/ProcessIdentity.swift
import Foundation

public struct ProcessIdentity: Codable, Equatable, Sendable {
    public let processID: Int32
    public let startedAt: Date?
    public let bundleIdentifier: String?

    public init(processID: Int32, startedAt: Date?, bundleIdentifier: String?) {
        self.processID = processID
        self.startedAt = startedAt
        self.bundleIdentifier = bundleIdentifier
    }
}

#if DEBUG
public extension ProcessIdentity {
    static let fixture = ProcessIdentity(
        processID: 123,
        startedAt: Date(timeIntervalSince1970: 100),
        bundleIdentifier: "com.openai.codex"
    )
}

public extension NormalizedEvent {
    static func testEvent(
        provider: AgentProvider,
        phase: SessionPhase,
        turnStartedAt: Date?
    ) -> Self {
        .init(
            schemaVersion: 1,
            provider: provider,
            surface: .cli,
            sessionID: "\(provider.rawValue)-session",
            turnID: "turn",
            phase: phase,
            label: phase == .thinking ? "Thinking" : phase.rawValue,
            toolCategory: nil,
            projectName: "Klarity",
            workingDirectory: "/tmp/Klarity",
            sourceBundleID: "com.apple.Terminal",
            sourceProcessID: 123,
            sourceProcessStartedAt: Date(timeIntervalSince1970: 100),
            turnStartedAt: turnStartedAt,
            updatedAt: Date(timeIntervalSince1970: 120)
        )
    }
}
#endif
```

- [ ] **Step 5: Implement safe payload normalization**

```swift
// Sources/KlarityCore/Events/HookNormalizer.swift
import Foundation

public enum HookNormalizationError: Error {
    case missingSessionID
    case missingWorkingDirectory
}

public enum HookNormalizer {
    public static func normalize(
        provider: AgentProvider,
        event: HookEventKind,
        payload: [String: Any],
        environment: [String: String],
        processIdentity: ProcessIdentity?,
        previous: NormalizedEvent?,
        now: Date
    ) throws -> NormalizedEvent? {
        guard let sessionID = payload["session_id"] as? String, !sessionID.isEmpty else {
            throw HookNormalizationError.missingSessionID
        }
        guard let cwd = payload["cwd"] as? String, cwd.hasPrefix("/") else {
            throw HookNormalizationError.missingWorkingDirectory
        }

        if event == .notification {
            let type = (payload["notification_type"] as? String)?.lowercased() ?? ""
            let message = (payload["message"] as? String)?.lowercased() ?? ""
            let isPermission = type == "permission_prompt"
                || message.contains("permission")
                || message.contains("approve")
                || message.contains("allow")
            guard isPermission else { return nil }
        }

        let toolName = payload["tool_name"] as? String ?? ""
        let toolCategory = event == .preToolUse ? ToolCategory.classify(toolName) : nil
        let phase: SessionPhase
        let label: String

        switch event {
        case .sessionStart, .sessionEnd:
            phase = .idle
            label = "Idle"
        case .userPromptSubmit, .postToolUse:
            phase = .thinking
            label = "Thinking"
        case .preToolUse:
            phase = .usingTool
            label = toolCategory?.label ?? "Using tool"
        case .notification, .permissionRequest:
            phase = .permission
            label = "Awaiting permission"
        case .stop:
            phase = .completed
            label = "Completed"
        }

        let turnStartedAt: Date?
        switch event {
        case .userPromptSubmit:
            turnStartedAt = now
        case .sessionStart, .sessionEnd, .stop:
            turnStartedAt = nil
        default:
            turnStartedAt = previous?.turnStartedAt ?? now
        }

        let terminalBundleID = environment["__CFBundleIdentifier"]
        let surface: SourceSurface = environment["TERM_PROGRAM"] == nil ? .desktop : .cli
        let event = NormalizedEvent(
            schemaVersion: ProductMetadata.schemaVersion,
            provider: provider,
            surface: surface,
            sessionID: sanitizedID(sessionID),
            turnID: payload["turn_id"] as? String,
            phase: phase,
            label: label,
            toolCategory: toolCategory,
            projectName: URL(fileURLWithPath: cwd).lastPathComponent,
            workingDirectory: cwd,
            sourceBundleID: surface == .cli ? terminalBundleID : processIdentity?.bundleIdentifier,
            sourceProcessID: processIdentity?.processID,
            sourceProcessStartedAt: processIdentity?.startedAt,
            turnStartedAt: turnStartedAt,
            updatedAt: now
        )
        try event.validate()
        return event
    }

    private static func sanitizedID(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return String(raw.unicodeScalars.filter(allowed.contains).prefix(128))
    }
}
```

- [ ] **Step 6: Run focused and full non-UI tests**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HookNormalizerTests \
  CODE_SIGNING_ALLOWED=NO
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -skip-testing:KlarityUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both commands PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/KlarityCore/Events Sources/KlarityCore/Processes Tests
git commit -m "feat: normalize Codex and Claude events"
```

---

### Task 4: Persist atomic per-session state and implement the event helper

**Files:**
- Create: `Sources/KlarityCore/State/SessionKey.swift`
- Create: `Sources/KlarityCore/State/SessionStateStore.swift`
- Create: `Sources/KlarityCore/Processes/ProcessIdentityResolver.swift`
- Create: `Sources/KlarityCore/Helper/KlarityEventCommand.swift`
- Modify: `Sources/KlarityEvent/main.swift`
- Create: `Tests/KlarityCoreTests/SessionStateStoreTests.swift`
- Create: `Tests/KlarityEventTests/KlarityEventCommandTests.swift`

**Interfaces:**
- Produces: `SessionKey`, `SessionStateStoring`, `FileSessionStateStore`, `KlarityEventCommand.run(arguments:input:environment:now:) -> Int32`.
- Consumes: `HookNormalizer`, `NormalizedEvent`, and `ProcessIdentityResolver` through an injectable closure.

- [ ] **Step 1: Write failing atomic-write and command tests**

```swift
// Tests/KlarityCoreTests/SessionStateStoreTests.swift
import XCTest
@testable import KlarityCore

final class SessionStateStoreTests: XCTestCase {
    func testWriteLoadAndRemoveUseOneFilePerSession() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let event = NormalizedEvent.testEvent(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date(timeIntervalSince1970: 100)
        )

        try store.write(event)
        XCTAssertEqual(try store.loadAll(), [event])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)

        try store.remove(SessionKey(event))
        XCTAssertEqual(try store.loadAll(), [])
    }

    func testWriteRejectsSymlinkedSessionDirectory() throws {
        let root = temporaryDirectory()
        let target = root.appendingPathComponent("target")
        let link = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let store = FileSessionStateStore(directory: link)
        XCTAssertThrowsError(try store.write(.testEvent(
            provider: .claude,
            phase: .thinking,
            turnStartedAt: Date()
        )))
    }

    func testLoadAllIgnoresMalformedFilesWithoutDroppingValidSessions() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let event = NormalizedEvent.testEvent(
            provider: .codex,
            phase: .thinking,
            turnStartedAt: Date()
        )
        try store.write(event)
        try Data("not-json".utf8).write(
            to: directory.appendingPathComponent("malformed.json")
        )
        XCTAssertEqual(try store.loadAll(), [event])
    }
}
```

```swift
// Tests/KlarityEventTests/KlarityEventCommandTests.swift
import XCTest
@testable import KlarityCore

final class KlarityEventCommandTests: XCTestCase {
    func testCommandWritesNormalizedStateAndReturnsSuccess() throws {
        let directory = temporaryDirectory()
        let store = FileSessionStateStore(directory: directory)
        let command = KlarityEventCommand(
            store: store,
            processIdentity: { _, _ in .fixture }
        )
        let input = Data("""
        {"session_id":"codex-session","turn_id":"turn","cwd":"/tmp/Klarity","prompt":"SECRET"}
        """.utf8)

        let code = command.run(
            arguments: ["klarity-event", "codex", "UserPromptSubmit", "--klarity-hook"],
            input: input,
            environment: ["TERM_PROGRAM": "Apple_Terminal"],
            now: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(code, 0)
        let event = try XCTUnwrap(store.loadAll().first)
        XCTAssertEqual(event.phase, .thinking)
        XCTAssertFalse(String(decoding: try JSONEncoder.klarity.encode(event), as: UTF8.self).contains("SECRET"))
    }
}
```

- [ ] **Step 2: Run the focused tests and verify failure**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/SessionStateStoreTests \
  -only-testing:KlarityEventTests/KlarityEventCommandTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the store and command do not exist.

- [ ] **Step 3: Implement session keys and atomic state storage**

```swift
// Sources/KlarityCore/State/SessionKey.swift
import Foundation

public struct SessionKey: Hashable, Sendable {
    public let provider: AgentProvider
    public let sessionID: String

    public init(provider: AgentProvider, sessionID: String) {
        self.provider = provider
        self.sessionID = sessionID
    }

    public init(_ event: NormalizedEvent) {
        self.init(provider: event.provider, sessionID: event.sessionID)
    }

    public var filename: String {
        "\(provider.rawValue)-\(sessionID).json"
    }
}
```

```swift
// Sources/KlarityCore/State/SessionStateStore.swift
import Darwin
import Foundation

public enum SessionStateStoreError: Error {
    case unsafeDirectory
    case unsafeFile
}

public protocol SessionStateStoring {
    func write(_ event: NormalizedEvent) throws
    func loadAll() throws -> [NormalizedEvent]
    func load(_ key: SessionKey) throws -> NormalizedEvent?
    func remove(_ key: SessionKey) throws
}

public final class FileSessionStateStore: SessionStateStoring {
    public let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Klarity/Sessions", isDirectory: true)
    }

    public func write(_ event: NormalizedEvent) throws {
        try event.validate()
        try prepareDirectory()
        let destination = directory.appendingPathComponent(SessionKey(event).filename)
        try rejectSymlink(destination)
        let temporary = directory.appendingPathComponent(".\(UUID().uuidString).tmp")
        let data = try JSONEncoder.klarity.encode(event)
        try data.write(to: temporary, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    public func loadAll() throws -> [NormalizedEvent] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        try rejectSymlink(directory)
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .compactMap { url in
            do {
                try rejectSymlink(url)
                let event = try JSONDecoder.klarity.decode(
                    NormalizedEvent.self,
                    from: Data(contentsOf: url)
                )
                try event.validate()
                return event
            } catch {
                return nil
            }
        }
    }

    public func load(_ key: SessionKey) throws -> NormalizedEvent? {
        let url = directory.appendingPathComponent(key.filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        try rejectSymlink(url)
        let event = try JSONDecoder.klarity.decode(NormalizedEvent.self, from: Data(contentsOf: url))
        try event.validate()
        return event
    }

    public func remove(_ key: SessionKey) throws {
        let url = directory.appendingPathComponent(key.filename)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try rejectSymlink(url)
        try fileManager.removeItem(at: url)
    }

    private func prepareDirectory() throws {
        if fileManager.fileExists(atPath: directory.path) {
            try rejectSymlink(directory)
            let attributes = try fileManager.attributesOfItem(atPath: directory.path)
            let owner = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value
            if let owner, owner != getuid() {
                throw SessionStateStoreError.unsafeDirectory
            }
        } else {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private func rejectSymlink(_ url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            if errno == ENOENT { return }
            throw SessionStateStoreError.unsafeFile
        }
        if (info.st_mode & S_IFMT) == S_IFLNK {
            throw SessionStateStoreError.unsafeDirectory
        }
    }
}
```

Implementation note: `replaceItemAt` requires an existing destination. In the implementation, branch to `moveItem(at:to:)` when the destination does not exist, while keeping both paths atomic within the same directory.

- [ ] **Step 4: Implement the testable helper command**

```swift
// Sources/KlarityCore/Helper/KlarityEventCommand.swift
import Foundation
import KlarityCore

public struct KlarityEventCommand {
    private let store: SessionStateStoring
    private let processIdentity: (AgentProvider, [String: String]) -> ProcessIdentity?

    public init(
        store: SessionStateStoring,
        processIdentity: @escaping (AgentProvider, [String: String]) -> ProcessIdentity?
    ) {
        self.store = store
        self.processIdentity = processIdentity
    }

    public func run(
        arguments: [String],
        input: Data,
        environment: [String: String],
        now: Date
    ) -> Int32 {
        guard arguments.count >= 3,
              let provider = AgentProvider(rawValue: arguments[1]),
              let event = HookEventKind(rawValue: arguments[2]),
              let payload = try? JSONSerialization.jsonObject(with: input) as? [String: Any]
        else { return 64 }

        do {
            let sessionID = payload["session_id"] as? String ?? ""
            let previous = try store.load(SessionKey(provider: provider, sessionID: sessionID))
            guard let normalized = try HookNormalizer.normalize(
                provider: provider,
                event: event,
                payload: payload,
                environment: environment,
                processIdentity: processIdentity(provider, environment),
                previous: previous,
                now: now
            ) else { return 0 }

            if event == .sessionEnd {
                try store.remove(SessionKey(normalized))
            } else {
                try store.write(normalized)
            }
            return 0
        } catch {
            return 1
        }
    }
}
```

```swift
// Sources/KlarityCore/Processes/ProcessIdentityResolver.swift
import Foundation

public struct ProcessIdentityResolver {
    public static let live = ProcessIdentityResolver()

    public init() {}

    public func resolve(
        provider: AgentProvider,
        environment: [String: String]
    ) -> ProcessIdentity? {
        _ = provider
        _ = environment
        return nil
    }
}
```

```swift
// Sources/KlarityEvent/main.swift
import Foundation
import KlarityCore

let environment = ProcessInfo.processInfo.environment
let stateDirectory = environment["KLARITY_STATE_DIRECTORY"]
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? FileSessionStateStore.defaultDirectory
let store = FileSessionStateStore(directory: stateDirectory)
let command = KlarityEventCommand(
    store: store,
    processIdentity: { provider, environment in
        ProcessIdentityResolver.live.resolve(provider: provider, environment: environment)
    }
)
let code = command.run(
    arguments: CommandLine.arguments,
    input: FileHandle.standardInput.readDataToEndOfFile(),
    environment: environment,
    now: Date()
)
exit(code)
```

Task 6 replaces the initial resolver implementation with Darwin process inspection without changing its public interface.

- [ ] **Step 5: Run focused tests and invoke the built helper**

```bash
xcodegen generate
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/SessionStateStoreTests \
  -only-testing:KlarityEventTests/KlarityEventCommandTests \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project Klarity.xcodeproj \
  -scheme KlarityEvent \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Then pipe a fixture into the built helper with a temporary `HOME`:

```bash
tmp_home="$(mktemp -d)"
state_directory="$tmp_home/sessions"
KLARITY_STATE_DIRECTORY="$state_directory" \
  "$HOME/Library/Developer/Xcode/DerivedData/Klarity-"*/Build/Products/Debug/klarity-event \
  codex UserPromptSubmit --klarity-hook \
  < Tests/Fixtures/codex/stop.json
find "$state_directory" -name '*.json' -print
```

Expected: focused tests PASS and one state file is printed.

- [ ] **Step 6: Commit**

```bash
git add Sources/KlarityCore/State Sources/KlarityEvent Tests
git commit -m "feat: persist session state through native helper"
```

---

### Task 5: Resolve multi-session priority, completion, disconnection, and expiration

**Files:**
- Create: `Sources/KlarityCore/State/SessionSnapshot.swift`
- Create: `Sources/KlarityCore/State/SessionResolver.swift`
- Create: `Tests/KlarityCoreTests/SessionResolverTests.swift`

**Interfaces:**
- Produces: `SessionSnapshot`, `ResolvedSessions`, `ResolutionMemory`, `SessionResolver.resolve(events:now:memory:isProcessAlive:)`.
- Consumes: `NormalizedEvent`, `SessionPhase`, and process-liveness results.

- [ ] **Step 1: Write failing priority and lifecycle tests**

```swift
// Tests/KlarityCoreTests/SessionResolverTests.swift
import XCTest
@testable import KlarityCore

final class SessionResolverTests: XCTestCase {
    func testPermissionOutranksWorkingAndCompleted() {
        let now = Date(timeIntervalSince1970: 1_000)
        let events = [
            event(provider: .codex, session: "working", phase: .usingTool, updated: 999),
            event(provider: .claude, session: "permission", phase: .permission, updated: 998),
            event(provider: .codex, session: "done", phase: .completed, updated: 997)
        ]
        var memory = ResolutionMemory()

        let resolved = SessionResolver.resolve(
            events: events,
            now: now,
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )

        XCTAssertEqual(resolved.dominantPhase, .permission)
        XCTAssertEqual(resolved.permissionCount, 1)
        XCTAssertEqual(resolved.sessions.map(\.sessionID), ["permission", "working", "done"])
    }

    func testCompletedBecomesIdleAfterEightSeconds() {
        let event = event(provider: .codex, session: "done", phase: .completed, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 109),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .idle)
    }

    func testDeadProcessBecomesDisconnected() {
        let event = event(provider: .claude, session: "dead", phase: .thinking, updated: 100)
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_000),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertEqual(resolved.sessions.first?.phase, .disconnected)

        let expired = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 1_016),
            memory: &memory,
            isProcessAlive: { _, _ in false }
        )
        XCTAssertTrue(expired.sessions.isEmpty)
    }

    func testUnknownProcessExpiresAfterFourHours() {
        var event = event(provider: .codex, session: "old", phase: .thinking, updated: 100)
        event = NormalizedEvent(
            schemaVersion: event.schemaVersion,
            provider: event.provider,
            surface: event.surface,
            sessionID: event.sessionID,
            turnID: event.turnID,
            phase: event.phase,
            label: event.label,
            toolCategory: event.toolCategory,
            projectName: event.projectName,
            workingDirectory: event.workingDirectory,
            sourceBundleID: event.sourceBundleID,
            sourceProcessID: nil,
            sourceProcessStartedAt: nil,
            turnStartedAt: event.turnStartedAt,
            updatedAt: event.updatedAt
        )
        var memory = ResolutionMemory()
        let resolved = SessionResolver.resolve(
            events: [event],
            now: Date(timeIntervalSince1970: 100 + 14_401),
            memory: &memory,
            isProcessAlive: { _, _ in true }
        )
        XCTAssertTrue(resolved.sessions.isEmpty)
    }
}

private func event(
    provider: AgentProvider,
    session: String,
    phase: SessionPhase,
    updated: TimeInterval
) -> NormalizedEvent {
    NormalizedEvent(
        schemaVersion: 1,
        provider: provider,
        surface: .cli,
        sessionID: session,
        turnID: "turn-\(session)",
        phase: phase,
        label: phase == .permission ? "Awaiting permission" : phase.rawValue,
        toolCategory: phase == .usingTool ? .edit : nil,
        projectName: session.capitalized,
        workingDirectory: "/tmp/\(session)",
        sourceBundleID: "com.apple.Terminal",
        sourceProcessID: 42,
        sourceProcessStartedAt: Date(timeIntervalSince1970: 50),
        turnStartedAt: Date(timeIntervalSince1970: 90),
        updatedAt: Date(timeIntervalSince1970: updated)
    )
}
```

- [ ] **Step 2: Run the focused test and verify failure**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/SessionResolverTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `SessionResolver` does not exist.

- [ ] **Step 3: Implement display snapshots and deterministic resolution**

```swift
// Sources/KlarityCore/State/SessionSnapshot.swift
import Foundation

public struct SessionSnapshot: Identifiable, Equatable, Sendable {
    public var id: String { "\(provider.rawValue):\(sessionID)" }
    public let provider: AgentProvider
    public let surface: SourceSurface
    public let sessionID: String
    public let phase: SessionPhase
    public let label: String
    public let projectName: String
    public let sourceBundleID: String?
    public let elapsedSeconds: Int?
    public let updatedAt: Date
}

public struct ResolvedSessions: Equatable, Sendable {
    public let sessions: [SessionSnapshot]
    public let dominantPhase: SessionPhase
    public let activeCount: Int
    public let permissionCount: Int
}

public struct ResolutionMemory: Sendable {
    public var disconnectedAt: [SessionKey: Date] = [:]

    public init() {}
}
```

```swift
// Sources/KlarityCore/State/SessionResolver.swift
import Foundation

public enum SessionResolver {
    public static let completionDisplayDuration: TimeInterval = 8
    public static let disconnectedDisplayDuration: TimeInterval = 15
    public static let unknownProcessExpiration: TimeInterval = 4 * 60 * 60
    public static let fileRetention: TimeInterval = 24 * 60 * 60

    public static func resolve(
        events: [NormalizedEvent],
        now: Date,
        memory: inout ResolutionMemory,
        isProcessAlive: (Int32, Date?) -> Bool
    ) -> ResolvedSessions {
        let snapshots = events.compactMap { event -> SessionSnapshot? in
            let age = now.timeIntervalSince(event.updatedAt)
            if age > fileRetention { return nil }

            let phase: SessionPhase
            if let pid = event.sourceProcessID {
                if !isProcessAlive(pid, event.sourceProcessStartedAt) {
                    let key = SessionKey(event)
                    let disconnectedAt = memory.disconnectedAt[key] ?? now
                    memory.disconnectedAt[key] = disconnectedAt
                    guard now.timeIntervalSince(disconnectedAt) <= disconnectedDisplayDuration else {
                        return nil
                    }
                    phase = .disconnected
                } else if event.phase == .completed && age > completionDisplayDuration {
                    memory.disconnectedAt.removeValue(forKey: SessionKey(event))
                    phase = .idle
                } else {
                    memory.disconnectedAt.removeValue(forKey: SessionKey(event))
                    phase = event.phase
                }
            } else {
                guard age <= unknownProcessExpiration else { return nil }
                phase = event.phase == .completed && age > completionDisplayDuration
                    ? .idle
                    : event.phase
            }

            return SessionSnapshot(
                provider: event.provider,
                surface: event.surface,
                sessionID: event.sessionID,
                phase: phase,
                label: phase == .idle ? "Idle" : phase == .disconnected ? "Disconnected" : event.label,
                projectName: event.projectName,
                sourceBundleID: event.sourceBundleID,
                elapsedSeconds: event.turnStartedAt.map { max(0, Int(now.timeIntervalSince($0))) },
                updatedAt: event.updatedAt
            )
        }
        .sorted(by: sort)

        let dominant = snapshots.map(\.phase).min(by: {
            priority($0) < priority($1)
        }) ?? .idle

        return ResolvedSessions(
            sessions: snapshots,
            dominantPhase: dominant,
            activeCount: snapshots.filter { [.thinking, .usingTool, .permission].contains($0.phase) }.count,
            permissionCount: snapshots.filter { $0.phase == .permission }.count
        )
    }

    private static func sort(_ lhs: SessionSnapshot, _ rhs: SessionSnapshot) -> Bool {
        let left = priority(lhs.phase)
        let right = priority(rhs.phase)
        if left != right { return left < right }
        return lhs.updatedAt > rhs.updatedAt
    }

    private static func priority(_ phase: SessionPhase) -> Int {
        switch phase {
        case .permission: 0
        case .usingTool: 1
        case .thinking: 2
        case .completed: 3
        case .disconnected: 4
        case .idle: 5
        }
    }
}
```

- [ ] **Step 4: Run focused and full tests**

Run:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/SessionResolverTests \
  CODE_SIGNING_ALLOWED=NO
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -skip-testing:KlarityUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/KlarityCore/State Tests/KlarityCoreTests/SessionResolverTests.swift
git commit -m "feat: resolve multi-session display state"
```

---

### Task 6: Detect provider processes and activate source applications

**Files:**
- Modify: `Sources/KlarityCore/Processes/ProcessIdentity.swift`
- Create: `Sources/KlarityCore/Processes/ProcessInspector.swift`
- Modify: `Sources/KlarityCore/Processes/ProcessIdentityResolver.swift`
- Create: `Sources/KlarityCore/Processes/SourceApplicationActivator.swift`
- Create: `Tests/KlarityCoreTests/ProcessIdentityResolverTests.swift`

**Interfaces:**
- Produces: `ProcessInspecting`, `DarwinProcessInspector`, `ProcessIdentityResolver.live`, `ProcessMonitoring`, `DarwinProcessMonitor`, `ApplicationActivating`, and `SourceApplicationActivator`.
- Consumes: `ProcessIdentity` and `SessionSnapshot`.

- [ ] **Step 1: Write failing process-resolution tests using a fake process table**

```swift
// Tests/KlarityCoreTests/ProcessIdentityResolverTests.swift
import XCTest
@testable import KlarityCore

final class ProcessIdentityResolverTests: XCTestCase {
    func testFindsNearestCodexAncestorAndKeepsTerminalBundleForActivation() {
        let inspector = FakeProcessInspector(
            parentPID: 30,
            rows: [
                30: .init(pid: 30, parentPID: 20, name: "zsh", startedAt: Date(timeIntervalSince1970: 30), bundleID: nil),
                20: .init(pid: 20, parentPID: 10, name: "codex", startedAt: Date(timeIntervalSince1970: 20), bundleID: nil),
                10: .init(pid: 10, parentPID: 1, name: "Terminal", startedAt: Date(timeIntervalSince1970: 10), bundleID: "com.apple.Terminal")
            ]
        )
        let resolver = ProcessIdentityResolver(inspector: inspector)

        let identity = resolver.resolve(
            provider: .codex,
            environment: ["TERM_PROGRAM": "Apple_Terminal", "__CFBundleIdentifier": "com.apple.Terminal"]
        )

        XCTAssertEqual(identity?.processID, 20)
        XCTAssertEqual(identity?.startedAt, Date(timeIntervalSince1970: 20))
        XCTAssertEqual(identity?.bundleIdentifier, "com.apple.Terminal")
    }

    func testDoesNotReturnUnrelatedAncestor() {
        let inspector = FakeProcessInspector(
            parentPID: 30,
            rows: [30: .init(pid: 30, parentPID: 1, name: "zsh", startedAt: nil, bundleID: nil)]
        )
        XCTAssertNil(ProcessIdentityResolver(inspector: inspector).resolve(
            provider: .claude,
            environment: [:]
        ))
    }

    func testFindsTerminalBundleFromAncestorWhenEnvironmentOmitsIt() {
        let inspector = FakeProcessInspector(
            parentPID: 20,
            rows: [
                20: .init(pid: 20, parentPID: 10, name: "codex", startedAt: Date(timeIntervalSince1970: 20), bundleID: nil),
                10: .init(pid: 10, parentPID: 1, name: "Terminal", startedAt: Date(timeIntervalSince1970: 10), bundleID: "com.apple.Terminal")
            ]
        )
        let identity = ProcessIdentityResolver(inspector: inspector).resolve(
            provider: .codex,
            environment: ["TERM_PROGRAM": "Apple_Terminal"]
        )
        XCTAssertEqual(identity?.bundleIdentifier, "com.apple.Terminal")
    }
}
```

- [ ] **Step 2: Run the focused tests and verify failure**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/ProcessIdentityResolverTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the process protocols and implementations do not exist.

- [ ] **Step 3: Implement the process inspection boundary and resolver**

```swift
// Sources/KlarityCore/Processes/ProcessInspector.swift
import AppKit
import Darwin
import Foundation

public struct InspectedProcess: Equatable, Sendable {
    public let pid: Int32
    public let parentPID: Int32
    public let name: String
    public let startedAt: Date?
    public let bundleID: String?
}

public protocol ProcessInspecting {
    var currentParentPID: Int32 { get }
    func process(_ pid: Int32) -> InspectedProcess?
}

public struct DarwinProcessInspector: ProcessInspecting {
    public var currentParentPID: Int32 { getppid() }

    public func process(_ pid: Int32) -> InspectedProcess? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }

        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        let name = String(cString: nameBuffer)
        let startedAt = info.pbi_start_tvsec > 0
            ? Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec))
            : nil
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        return InspectedProcess(
            pid: pid,
            parentPID: Int32(info.pbi_ppid),
            name: name,
            startedAt: startedAt,
            bundleID: bundleID
        )
    }
}
```

```swift
// Sources/KlarityCore/Processes/ProcessIdentityResolver.swift
import Foundation

public struct ProcessIdentityResolver {
    public static let live = ProcessIdentityResolver(inspector: DarwinProcessInspector())
    private let inspector: ProcessInspecting

    public init(inspector: ProcessInspecting) {
        self.inspector = inspector
    }

    public func resolve(
        provider: AgentProvider,
        environment: [String: String]
    ) -> ProcessIdentity? {
        let expectedNames = provider == .codex
            ? ["codex", "Codex"]
            : ["claude", "Claude"]
        let isCLI = environment["TERM_PROGRAM"] != nil
        var agentProcess: InspectedProcess?
        var sourceBundle = isCLI ? environment["__CFBundleIdentifier"] : nil
        var pid = inspector.currentParentPID

        for _ in 0..<12 {
            guard pid > 1, let row = inspector.process(pid) else { break }
            if agentProcess == nil,
               expectedNames.contains(where: { row.name.localizedCaseInsensitiveContains($0) }) {
                agentProcess = row
                if !isCLI { sourceBundle = row.bundleID }
            }
            if isCLI, sourceBundle == nil, let bundleID = row.bundleID {
                sourceBundle = bundleID
            }
            if let agentProcess, sourceBundle != nil {
                return ProcessIdentity(
                    processID: agentProcess.pid,
                    startedAt: agentProcess.startedAt,
                    bundleIdentifier: sourceBundle
                )
            }
            pid = row.parentPID
        }
        guard let agentProcess else { return nil }
        return ProcessIdentity(
            processID: agentProcess.pid,
            startedAt: agentProcess.startedAt,
            bundleIdentifier: sourceBundle
        )
    }
}
```

- [ ] **Step 4: Implement process liveness and app activation**

```swift
// Sources/KlarityCore/Processes/SourceApplicationActivator.swift
import AppKit
import Darwin
import Foundation

public protocol ProcessMonitoring {
    func isAlive(processID: Int32, startedAt: Date?) -> Bool
}

public struct DarwinProcessMonitor: ProcessMonitoring {
    private let inspector: ProcessInspecting

    public init(inspector: ProcessInspecting = DarwinProcessInspector()) {
        self.inspector = inspector
    }

    public func isAlive(processID: Int32, startedAt: Date?) -> Bool {
        guard kill(processID, 0) == 0, let current = inspector.process(processID) else {
            return false
        }
        guard let expected = startedAt, let actual = current.startedAt else { return true }
        return abs(actual.timeIntervalSince(expected)) < 1
    }
}

public protocol ApplicationActivating {
    @discardableResult
    func activate(bundleIdentifier: String?) -> Bool
}

public struct SourceApplicationActivator: ApplicationActivating {
    public init() {}

    @discardableResult
    public func activate(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier,
              let application = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
              ).first else {
            return false
        }
        return application.activate(options: [.activateAllWindows])
    }
}
```

- [ ] **Step 5: Add fake implementations in the test target and run tests**

```swift
private struct FakeProcessInspector: ProcessInspecting {
    let parentPID: Int32
    let rows: [Int32: InspectedProcess]
    var currentParentPID: Int32 { parentPID }
    func process(_ pid: Int32) -> InspectedProcess? { rows[pid] }
}
```

Run:

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/ProcessIdentityResolverTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 6: Run all non-UI tests and commit**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -skip-testing:KlarityUITests \
  CODE_SIGNING_ALLOWED=NO
git add Sources/KlarityCore/Processes Tests/KlarityCoreTests
git commit -m "feat: track agent processes and activate source apps"
```

---

### Task 7: Build the observable app model and native menu bar interface

**Files:**
- Create: `Sources/KlarityApp/AppModel.swift`
- Create: `Sources/KlarityApp/MenuBar/StatusPresentation.swift`
- Create: `Sources/KlarityApp/MenuBar/StatusItemController.swift`
- Create: `Sources/KlarityApp/MenuBar/SessionListView.swift`
- Create: `Sources/KlarityApp/MenuBar/SessionRowView.swift`
- Modify: `Sources/KlarityApp/AppDelegate.swift`
- Create: `Tests/KlarityAppTests/AppModelTests.swift`
- Create: `Tests/KlarityAppTests/StatusPresentationTests.swift`

**Interfaces:**
- Produces: `AppModel`, `StatusPresentation`, `StatusItemController`, `SessionListView`, and `SessionRowView`.
- Consumes: `SessionStateStoring`, `SessionResolver`, `ProcessMonitoring`, and `ApplicationActivating`.

- [ ] **Step 1: Write failing app-model and presentation tests**

```swift
// Tests/KlarityAppTests/AppModelTests.swift
import XCTest
@testable import Klarity
@testable import KlarityCore

@MainActor
final class AppModelTests: XCTestCase {
    func testRefreshLoadsAndResolvesMultipleSessions() throws {
        let store = InMemorySessionStore(events: [
            .testEvent(provider: .codex, phase: .thinking, turnStartedAt: Date(timeIntervalSince1970: 90)),
            .testEvent(provider: .claude, phase: .permission, turnStartedAt: Date(timeIntervalSince1970: 80))
        ])
        let model = AppModel(
            store: store,
            processMonitor: AlwaysAliveProcessMonitor(),
            activator: RecordingActivator(),
            now: { Date(timeIntervalSince1970: 100) }
        )

        model.refresh()

        XCTAssertEqual(model.resolved.sessions.count, 2)
        XCTAssertEqual(model.resolved.dominantPhase, .permission)
    }
}

private final class InMemorySessionStore: SessionStateStoring {
    var events: [NormalizedEvent]
    init(events: [NormalizedEvent]) { self.events = events }
    func write(_ event: NormalizedEvent) { events.removeAll { SessionKey($0) == SessionKey(event) }; events.append(event) }
    func loadAll() -> [NormalizedEvent] { events }
    func load(_ key: SessionKey) -> NormalizedEvent? { events.first { SessionKey($0) == key } }
    func remove(_ key: SessionKey) { events.removeAll { SessionKey($0) == key } }
}

private struct AlwaysAliveProcessMonitor: ProcessMonitoring {
    func isAlive(processID: Int32, startedAt: Date?) -> Bool { true }
}

private final class RecordingActivator: ApplicationActivating {
    private(set) var bundleIdentifiers: [String?] = []
    func activate(bundleIdentifier: String?) -> Bool {
        bundleIdentifiers.append(bundleIdentifier)
        return true
    }
}
```

```swift
// Tests/KlarityAppTests/StatusPresentationTests.swift
import XCTest
@testable import Klarity
@testable import KlarityCore

final class StatusPresentationTests: XCTestCase {
    func testPermissionPresentationUsesAttentionStateAndCount() {
        let presentation = StatusPresentation(
            resolved: .init(sessions: [], dominantPhase: .permission, activeCount: 3, permissionCount: 2),
            showTimer: true,
            reduceMotion: false
        )
        XCTAssertEqual(presentation.accessibilityLabel, "Klarity, 2 sessions need permission")
        XCTAssertEqual(presentation.symbolName, "exclamationmark.circle.fill")
        XCTAssertFalse(presentation.animates)
    }

    func testWorkingPresentationShowsOptionalTimer() {
        let session = SessionSnapshot(
            provider: .codex,
            surface: .cli,
            sessionID: "session",
            phase: .thinking,
            label: "Thinking",
            projectName: "Klarity",
            sourceBundleID: "com.apple.Terminal",
            elapsedSeconds: 65,
            updatedAt: Date()
        )
        let presentation = StatusPresentation(
            resolved: .init(sessions: [session], dominantPhase: .thinking, activeCount: 1, permissionCount: 0),
            showTimer: true,
            reduceMotion: false
        )
        XCTAssertEqual(presentation.title, "1m 5s")
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityAppTests/AppModelTests \
  -only-testing:KlarityAppTests/StatusPresentationTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the app model and status presentation do not exist.

- [ ] **Step 3: Implement the main-actor app model**

```swift
// Sources/KlarityApp/AppModel.swift
import Foundation
import Observation
import KlarityCore

@MainActor
@Observable
final class AppModel {
    private let store: SessionStateStoring
    private let processMonitor: ProcessMonitoring
    private let activator: ApplicationActivating
    private let now: () -> Date
    private var timer: Timer?
    private var resolutionMemory = ResolutionMemory()

    var resolved = ResolvedSessions(
        sessions: [],
        dominantPhase: .idle,
        activeCount: 0,
        permissionCount: 0
    )
    var showTimer = false
    var reduceMotion = false

    init(
        store: SessionStateStoring,
        processMonitor: ProcessMonitoring,
        activator: ApplicationActivating,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.processMonitor = processMonitor
        self.activator = activator
        self.now = now
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let events = (try? store.loadAll()) ?? []
        let currentTime = now()
        for event in events where currentTime.timeIntervalSince(event.updatedAt) > SessionResolver.fileRetention {
            try? store.remove(SessionKey(event))
        }
        resolved = SessionResolver.resolve(
            events: events,
            now: currentTime,
            memory: &resolutionMemory,
            isProcessAlive: { [processMonitor] pid, startedAt in
                processMonitor.isAlive(processID: pid, startedAt: startedAt)
            }
        )
    }

    func activate(_ session: SessionSnapshot) {
        activator.activate(bundleIdentifier: session.sourceBundleID)
    }
}
```

- [ ] **Step 4: Implement pure status presentation**

```swift
// Sources/KlarityApp/MenuBar/StatusPresentation.swift
import AppKit
import KlarityCore

struct StatusPresentation: Equatable {
    let symbolName: String
    let title: String
    let accessibilityLabel: String
    let color: NSColor
    let animates: Bool

    init(resolved: ResolvedSessions, showTimer: Bool, reduceMotion: Bool) {
        switch resolved.dominantPhase {
        case .permission:
            symbolName = "exclamationmark.circle.fill"
            title = resolved.permissionCount > 1 ? "\(resolved.permissionCount)" : ""
            accessibilityLabel = "Klarity, \(resolved.permissionCount) sessions need permission"
            color = .systemYellow
            animates = false
        case .usingTool, .thinking:
            symbolName = "sparkle"
            let active = resolved.sessions.first {
                [.usingTool, .thinking].contains($0.phase)
            }
            let timer = showTimer ? active?.elapsedSeconds.map(Self.format) : nil
            let count = resolved.activeCount > 1 ? "\(resolved.activeCount)" : nil
            title = [count, timer].compactMap { $0 }.joined(separator: " · ")
            accessibilityLabel = "Klarity, \(resolved.activeCount) active sessions"
            color = .controlAccentColor
            animates = !reduceMotion
        case .completed:
            symbolName = "checkmark.circle.fill"
            title = ""
            accessibilityLabel = "Klarity, session completed"
            color = .systemGreen
            animates = false
        case .disconnected:
            symbolName = "bolt.slash.circle"
            title = ""
            accessibilityLabel = "Klarity, integration disconnected"
            color = .secondaryLabelColor
            animates = false
        case .idle:
            symbolName = "circle.hexagongrid"
            title = ""
            accessibilityLabel = "Klarity, idle"
            color = .labelColor
            animates = false
        }
    }

    private static func format(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
}
```

- [ ] **Step 5: Implement the status item, popover, and session rows**

```swift
// Sources/KlarityApp/MenuBar/StatusItemController.swift
import AppKit
import SwiftUI
import KlarityCore

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let openIntegrations: () -> Void
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var animationTimer: Timer?

    init(model: AppModel, openIntegrations: @escaping () -> Void) {
        self.model = model
        self.openIntegrations = openIntegrations
        super.init()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: SessionListView(
                model: model,
                openIntegrations: openIntegrations
            )
        )
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.identifier = NSUserInterfaceItemIdentifier("Klarity.StatusItem")
        item.button?.setAccessibilityLabel("Klarity")
        update()
    }

    func update() {
        let presentation = StatusPresentation(
            resolved: model.resolved,
            showTimer: model.showTimer,
            reduceMotion: model.reduceMotion
        )
        let image = NSImage(systemSymbolName: presentation.symbolName, accessibilityDescription: nil)
        image?.isTemplate = false
        item.button?.image = image
        item.button?.contentTintColor = presentation.color
        item.button?.title = presentation.title.isEmpty ? "" : " \(presentation.title)"
        item.button?.setAccessibilityLabel(presentation.accessibilityLabel)
        configureAnimation(enabled: presentation.animates)
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func configureAnimation(enabled: Bool) {
        if !enabled {
            animationTimer?.invalidate()
            animationTimer = nil
            item.button?.alphaValue = 1
        } else if animationTimer == nil {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
                guard let button = self?.item.button else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    button.animator().alphaValue = button.alphaValue < 1 ? 1 : 0.55
                }
            }
        }
    }
}
```

```swift
// Sources/KlarityApp/MenuBar/SessionListView.swift
import SwiftUI
import KlarityCore

struct SessionListView: View {
    @Bindable var model: AppModel
    let openIntegrations: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.headline)
                .accessibilityIdentifier("Klarity.SessionSummary")

            if model.resolved.sessions.isEmpty {
                ContentUnavailableView(
                    "No active sessions",
                    systemImage: "circle.hexagongrid",
                    description: Text("Start Codex or Claude to see live status.")
                )
            } else {
                ForEach(AgentProvider.allCases, id: \.self) { provider in
                    let sessions = model.resolved.sessions.filter { $0.provider == provider }
                    if !sessions.isEmpty {
                        Section(provider == .codex ? "Codex" : "Claude") {
                            ForEach(sessions) { session in
                                SessionRowView(session: session) {
                                    model.activate(session)
                                }
                            }
                        }
                    }
                }
            }

            Divider()
            HStack {
                Button("Integrations", action: openIntegrations)
                SettingsLink { Text("Settings") }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var summary: String {
        let count = model.resolved.sessions.count
        return count == 1 ? "1 session" : "\(count) sessions"
    }
}
```

```swift
// Sources/KlarityApp/MenuBar/SessionRowView.swift
import SwiftUI
import KlarityCore

struct SessionRowView: View {
    let session: SessionSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.projectName).font(.body.weight(.medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let elapsed = session.elapsedSeconds,
                   [.thinking, .usingTool].contains(session.phase) {
                    Text(format(elapsed))
                        .monospacedDigit()
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(session.projectName), \(session.label), \(session.surface.rawValue)")
    }

    private var detail: String { "\(session.label) · \(session.surface.rawValue.capitalized)" }
    private var icon: String { session.phase == .permission ? "exclamationmark.circle.fill" : "sparkle" }
    private var color: Color { session.phase == .permission ? .yellow : .accentColor }
    private func format(_ seconds: Int) -> String { seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s" }
}
```

- [ ] **Step 6: Wire the model and status item in `AppDelegate`**

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItemController: StatusItemController!
    private var observationTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel(
            store: FileSessionStateStore(directory: FileSessionStateStore.defaultDirectory),
            processMonitor: DarwinProcessMonitor(),
            activator: SourceApplicationActivator()
        )
        statusItemController = StatusItemController(
            model: model,
            openIntegrations: {}
        )
        model.start()
        observationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.statusItemController.update()
        }
    }
}
```

- [ ] **Step 7: Run app-model tests and a local launch smoke test**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityAppTests \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -configuration Debug \
  -destination 'platform=macOS'
open "$HOME/Library/Developer/Xcode/DerivedData/Klarity-"*/Build/Products/Debug/Klarity.app
```

Expected: tests PASS, Klarity launches without a Dock icon, and one idle status item appears.

- [ ] **Step 8: Commit**

```bash
git add Sources/KlarityApp Tests/KlarityAppTests
git commit -m "feat: add native multi-session menu bar"
```

---

### Task 8: Safely install, repair, diagnose, and remove provider hooks

**Files:**
- Create: `Sources/KlarityCore/Integrations/HookDefinitionFactory.swift`
- Create: `Sources/KlarityCore/Integrations/JSONConfigEditor.swift`
- Create: `Sources/KlarityCore/Integrations/IntegrationStatus.swift`
- Create: `Sources/KlarityCore/Integrations/ClaudeIntegrationManager.swift`
- Create: `Sources/KlarityCore/Integrations/CodexIntegrationManager.swift`
- Create: `Tests/KlarityCoreTests/JSONConfigEditorTests.swift`
- Create: `Tests/KlarityCoreTests/ClaudeIntegrationManagerTests.swift`
- Create: `Tests/KlarityCoreTests/CodexIntegrationManagerTests.swift`

**Interfaces:**
- Produces: `HookDefinitionFactory`, `JSONConfigEditor`, `IntegrationStatus`, `ProviderIntegrationManaging`, `ClaudeIntegrationManager`, and `CodexIntegrationManager`.
- Consumes: installed helper URL and provider event lists.

- [ ] **Step 1: Write failing idempotent-merge and removal tests**

```swift
// Tests/KlarityCoreTests/ClaudeIntegrationManagerTests.swift
import XCTest
@testable import KlarityCore

final class ClaudeIntegrationManagerTests: XCTestCase {
    func testInstallPreservesExistingHooksAndIsIdempotent() throws {
        let settings = temporaryFile(contents: """
        {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"existing-policy"}]}]}}
        """)
        let manager = ClaudeIntegrationManager(
            settingsURL: settings,
            helperURL: URL(fileURLWithPath: "/tmp/klarity-event")
        )

        try manager.install()
        try manager.install()

        let object = try jsonObject(settings)
        let text = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        XCTAssertTrue(text.contains("existing-policy"))
        XCTAssertEqual(text.components(separatedBy: "--klarity-hook").count - 1, 8)
    }

    func testRemoveDeletesOnlyKlarityHooks() throws {
        let settings = temporaryFile(contents: configuredClaudeSettings())
        let manager = ClaudeIntegrationManager(
            settingsURL: settings,
            helperURL: URL(fileURLWithPath: "/tmp/klarity-event")
        )
        try manager.remove()
        let text = try String(contentsOf: settings)
        XCTAssertTrue(text.contains("existing-policy"))
        XCTAssertFalse(text.contains("--klarity-hook"))
    }
}
```

```swift
// Tests/KlarityCoreTests/CodexIntegrationManagerTests.swift
import XCTest
@testable import KlarityCore

final class CodexIntegrationManagerTests: XCTestCase {
    func testInstallCreatesSixSupportedEventsAndTrustMessage() throws {
        let hooks = temporaryFile(contents: "{}")
        let manager = CodexIntegrationManager(
            hooksURL: hooks,
            helperURL: URL(fileURLWithPath: "/tmp/klarity-event")
        )
        try manager.install()
        let status = try manager.status()
        XCTAssertTrue(status.installed)
        XCTAssertTrue(status.requiresTrustReview)
        XCTAssertEqual(status.installedEvents.count, 6)
    }
}

private func temporaryFile(contents: String) -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("config.json")
    try! Data(contents.utf8).write(to: url)
    return url
}

private func jsonObject(_ url: URL) throws -> [String: Any] {
    try XCTUnwrap(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    )
}

private func configuredClaudeSettings() -> String {
    """
    {
      "hooks": {
        "PreToolUse": [
          {"matcher":"Bash","hooks":[{"type":"command","command":"existing-policy"}]},
          {"matcher":"*","hooks":[{"type":"command","command":"\\"/tmp/klarity-event\\" claude PreToolUse --klarity-hook"}]}
        ]
      }
    }
    """
}
```

- [ ] **Step 2: Run focused tests and verify failure**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/ClaudeIntegrationManagerTests \
  -only-testing:KlarityCoreTests/CodexIntegrationManagerTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the integration managers do not exist.

- [ ] **Step 3: Implement exact hook commands and integration status**

```swift
// Sources/KlarityCore/Integrations/IntegrationStatus.swift
import Foundation

public struct IntegrationStatus: Equatable, Sendable {
    public let provider: AgentProvider
    public let installed: Bool
    public let requiresTrustReview: Bool
    public let installedEvents: [HookEventKind]
    public let issue: String?
}

public protocol ProviderIntegrationManaging {
    var provider: AgentProvider { get }
    func install() throws
    func repair() throws
    func remove() throws
    func status() throws -> IntegrationStatus
}
```

```swift
// Sources/KlarityCore/Integrations/HookDefinitionFactory.swift
import Foundation

public enum HookDefinitionFactory {
    public static let marker = "--klarity-hook"

    public static func command(
        helperURL: URL,
        provider: AgentProvider,
        event: HookEventKind
    ) -> String {
        "\"\(helperURL.path)\" \(provider.rawValue) \(event.rawValue) \(marker)"
    }

    public static func entry(
        helperURL: URL,
        provider: AgentProvider,
        event: HookEventKind
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": command(helperURL: helperURL, provider: provider, event: event),
                "timeout": 5
            ]]
        ]
        if [.preToolUse, .postToolUse, .permissionRequest].contains(event) {
            entry["matcher"] = "*"
        }
        return entry
    }
}
```

- [ ] **Step 4: Implement safe JSON backup, mutation, and atomic replacement**

```swift
// Sources/KlarityCore/Integrations/JSONConfigEditor.swift
import Darwin
import Foundation

public final class JSONConfigEditor {
    private let url: URL
    private let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    public func mutate(_ change: (inout [String: Any]) throws -> Void) throws {
        try ensureSafeParent()
        var object: [String: Any] = [:]
        if fileManager.fileExists(atPath: url.path) {
            try rejectSymlink(url)
            try rejectUnexpectedOwner(url)
            let data = try Data(contentsOf: url)
            object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            try writeFirstBackupIfNeeded(data)
        } else {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        try change(&object)
        guard JSONSerialization.isValidJSONObject(object) else {
            throw CocoaError(.propertyListWriteInvalid)
        }
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) + Data("\n".utf8)
        _ = try JSONSerialization.jsonObject(with: data)

        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: url.path) {
            _ = try fileManager.replaceItemAt(url, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: url)
        }
    }

    private func writeFirstBackupIfNeeded(_ data: Data) throws {
        let directory = url.deletingLastPathComponent()
        let prefix = "\(url.lastPathComponent)."
        let existing = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).contains {
            $0.lastPathComponent.hasPrefix(prefix)
                && $0.lastPathComponent.hasSuffix(".bak-klarity")
        }
        guard !existing else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backup = directory.appendingPathComponent(
            "\(prefix)\(formatter.string(from: Date())).bak-klarity"
        )
        try data.write(to: backup, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
    }

    private func ensureSafeParent() throws {
        let parent = url.deletingLastPathComponent()
        if fileManager.fileExists(atPath: parent.path) {
            try rejectSymlink(parent)
            try rejectUnexpectedOwner(parent)
        }
    }

    private func rejectSymlink(_ candidate: URL) throws {
        let values = try candidate.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true { throw SessionStateStoreError.unsafeFile }
    }

    private func rejectUnexpectedOwner(_ candidate: URL) throws {
        let attributes = try fileManager.attributesOfItem(atPath: candidate.path)
        let owner = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value
        if let owner, owner != getuid() {
            throw CocoaError(.fileWriteNoPermission)
        }
    }
}
```

- [ ] **Step 5: Implement Claude and Codex managers**

```swift
// Sources/KlarityCore/Integrations/ClaudeIntegrationManager.swift
import Foundation

public final class ClaudeIntegrationManager: ProviderIntegrationManaging {
    public let provider: AgentProvider = .claude
    private let settingsURL: URL
    private let helperURL: URL
    private let events: [HookEventKind] = [
        .sessionStart, .sessionEnd, .userPromptSubmit, .preToolUse,
        .postToolUse, .notification, .permissionRequest, .stop
    ]

    public init(settingsURL: URL, helperURL: URL) {
        self.settingsURL = settingsURL
        self.helperURL = helperURL
    }

    public func install() throws { try rewrite(add: true) }
    public func repair() throws { try rewrite(add: true) }
    public func remove() throws { try rewrite(add: false) }

    public func status() throws -> IntegrationStatus {
        let installed = try installedEvents()
        return IntegrationStatus(
            provider: .claude,
            installed: Set(installed) == Set(events),
            requiresTrustReview: false,
            installedEvents: installed,
            issue: Set(installed) == Set(events) ? nil : "Claude hooks need installation or repair."
        )
    }

    private func rewrite(add: Bool) throws {
        try JSONConfigEditor(url: settingsURL).mutate { object in
            var hooks = object["hooks"] as? [String: Any] ?? [:]
            for event in events {
                var entries = hooks[event.rawValue] as? [[String: Any]] ?? []
                entries = entries.filter { !Self.containsMarker($0) }
                if add {
                    entries.append(HookDefinitionFactory.entry(
                        helperURL: helperURL,
                        provider: .claude,
                        event: event
                    ))
                }
                if entries.isEmpty { hooks.removeValue(forKey: event.rawValue) }
                else { hooks[event.rawValue] = entries }
            }
            object["hooks"] = hooks
        }
    }

    private func installedEvents() throws -> [HookEventKind] {
        guard let data = try? Data(contentsOf: settingsURL),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = object["hooks"] as? [String: Any] else { return [] }
        return events.filter { event in
            (hooks[event.rawValue] as? [[String: Any]] ?? []).contains(where: containsCurrentHook)
        }
    }

    private func containsCurrentHook(_ entry: [String: Any]) -> Bool {
        let handlers = entry["hooks"] as? [[String: Any]] ?? []
        return handlers.contains {
            let command = $0["command"] as? String ?? ""
            return command.contains(HookDefinitionFactory.marker)
                && command.contains(helperURL.path)
        }
    }

    private static func containsMarker(_ entry: [String: Any]) -> Bool {
        let handlers = entry["hooks"] as? [[String: Any]] ?? []
        return handlers.contains { ($0["command"] as? String)?.contains(HookDefinitionFactory.marker) == true }
    }
}
```

```swift
// Sources/KlarityCore/Integrations/CodexIntegrationManager.swift
import Foundation

public final class CodexIntegrationManager: ProviderIntegrationManaging {
    public static let trustInstruction =
        "Open Codex, run /hooks, review the Klarity entries, and choose Trust."

    public let provider: AgentProvider = .codex
    private let hooksURL: URL
    private let helperURL: URL
    private let events: [HookEventKind] = [
        .sessionStart, .userPromptSubmit, .preToolUse,
        .postToolUse, .permissionRequest, .stop
    ]

    public init(hooksURL: URL, helperURL: URL) {
        self.hooksURL = hooksURL
        self.helperURL = helperURL
    }

    public func install() throws { try rewrite(add: true) }
    public func repair() throws { try rewrite(add: true) }
    public func remove() throws { try rewrite(add: false) }

    public func status() throws -> IntegrationStatus {
        let installed = try installedEvents()
        let complete = Set(installed) == Set(events)
        return IntegrationStatus(
            provider: .codex,
            installed: complete,
            requiresTrustReview: !installed.isEmpty,
            installedEvents: installed,
            issue: complete ? Self.trustInstruction : "Codex hooks need installation or repair."
        )
    }

    private func rewrite(add: Bool) throws {
        try JSONConfigEditor(url: hooksURL).mutate { object in
            var hooks = object["hooks"] as? [String: Any] ?? [:]
            for event in events {
                var entries = hooks[event.rawValue] as? [[String: Any]] ?? []
                entries = entries.filter { !Self.containsMarker($0) }
                if add {
                    entries.append(HookDefinitionFactory.entry(
                        helperURL: helperURL,
                        provider: .codex,
                        event: event
                    ))
                }
                if entries.isEmpty {
                    hooks.removeValue(forKey: event.rawValue)
                } else {
                    hooks[event.rawValue] = entries
                }
            }
            object["hooks"] = hooks
        }
    }

    private func installedEvents() throws -> [HookEventKind] {
        guard let data = try? Data(contentsOf: hooksURL),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = object["hooks"] as? [String: Any] else { return [] }
        return events.filter { event in
            (hooks[event.rawValue] as? [[String: Any]] ?? [])
                .contains(where: containsCurrentHook)
        }
    }

    private func containsCurrentHook(_ entry: [String: Any]) -> Bool {
        let handlers = entry["hooks"] as? [[String: Any]] ?? []
        return handlers.contains {
            let command = $0["command"] as? String ?? ""
            return command.contains(HookDefinitionFactory.marker)
                && command.contains(helperURL.path)
        }
    }

    private static func containsMarker(_ entry: [String: Any]) -> Bool {
        let handlers = entry["hooks"] as? [[String: Any]] ?? []
        return handlers.contains {
            ($0["command"] as? String)?.contains(HookDefinitionFactory.marker) == true
        }
    }
}
```

- [ ] **Step 6: Run integration tests and verify real temporary config output**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/JSONConfigEditorTests \
  -only-testing:KlarityCoreTests/ClaudeIntegrationManagerTests \
  -only-testing:KlarityCoreTests/CodexIntegrationManagerTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: tests PASS, repeated installation does not duplicate entries, and removal preserves unrelated commands.

- [ ] **Step 7: Commit**

```bash
git add Sources/KlarityCore/Integrations Tests/KlarityCoreTests
git commit -m "feat: manage Claude and Codex integrations safely"
```

---

### Task 9: Implement helper installation, setup, diagnostics, repair, and launch at login

**Files:**
- Create: `Sources/KlarityCore/Integrations/HelperInstaller.swift`
- Create: `Sources/KlarityCore/Integrations/ExecutableLocator.swift`
- Create: `Sources/KlarityCore/Integrations/ProviderVersionDetector.swift`
- Create: `Sources/KlarityApp/Setup/SetupViewModel.swift`
- Create: `Sources/KlarityApp/Setup/SetupView.swift`
- Create: `Sources/KlarityApp/Services/SyntheticEventService.swift`
- Create: `Sources/KlarityApp/Services/LaunchAtLoginService.swift`
- Modify: `Sources/KlarityApp/KlarityApp.swift`
- Modify: `Sources/KlarityApp/AppDelegate.swift`
- Create: `Tests/KlarityCoreTests/HelperInstallerTests.swift`
- Create: `Tests/KlarityAppTests/SetupViewModelTests.swift`

**Interfaces:**
- Produces: `HelperInstalling`, `HelperInstaller`, `ExecutableLocator`, `ProviderVersionDetector`, `SetupViewModel`, `SyntheticEventService`, and `LaunchAtLoginService`.
- Consumes: provider integration managers, embedded `klarity-event`, and `FileSessionStateStore`.

- [ ] **Step 1: Write failing helper-installation and setup tests**

```swift
// Tests/KlarityCoreTests/HelperInstallerTests.swift
import XCTest
@testable import KlarityCore

final class HelperInstallerTests: XCTestCase {
    func testInstallCopiesExecutableAndSetsUserOnlyDirectoryPermissions() throws {
        let root = temporaryDirectory()
        let source = root.appendingPathComponent("source-helper")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.path)
        let destination = root.appendingPathComponent("Application Support/Klarity/bin/klarity-event")
        let installer = HelperInstaller(sourceURL: source, destinationURL: destination)

        try installer.install()

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: destination.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, 0o755)
    }

    func testVersionParserExtractsCodexAndClaudeVersions() {
        XCTAssertEqual(
            ProviderVersionDetector.parseVersion("codex-cli 0.133.0"),
            "0.133.0"
        )
        XCTAssertEqual(
            ProviderVersionDetector.parseVersion("2.1.185 (Claude Code)"),
            "2.1.185"
        )
    }
}
```

```swift
// Tests/KlarityAppTests/SetupViewModelTests.swift
import XCTest
@testable import Klarity
@testable import KlarityCore

@MainActor
final class SetupViewModelTests: XCTestCase {
    func testInstallRunsHelperThenProviderThenSyntheticTest() async {
        let recorder = SetupRecorder()
        let model = SetupViewModel(
            provider: .codex,
            executableURL: URL(fileURLWithPath: "/tmp/codex"),
            helperInstaller: recorder,
            integration: recorder,
            syntheticEventService: recorder
        )

        await model.install()

        XCTAssertEqual(recorder.calls, ["install-helper", "install-hooks", "synthetic-test"])
        XCTAssertEqual(model.phase, .needsTrust)
    }
}

private final class SetupRecorder:
    HelperInstalling,
    ProviderIntegrationManaging,
    SyntheticEventTesting
{
    let destinationURL = URL(fileURLWithPath: "/tmp/klarity-event")
    let provider: AgentProvider = .codex
    var calls: [String] = []

    func install() throws {
        if calls.isEmpty { calls.append("install-helper") }
        else { calls.append("install-hooks") }
    }

    func isCurrent() -> Bool { true }
    func repair() throws { calls.append("repair-hooks") }
    func remove() throws { calls.append("remove-hooks") }
    func status() throws -> IntegrationStatus {
        .init(
            provider: .codex,
            installed: true,
            requiresTrustReview: true,
            installedEvents: [],
            issue: nil
        )
    }

    func run(provider: AgentProvider, helperURL: URL) throws -> Bool {
        calls.append("synthetic-test")
        return true
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HelperInstallerTests \
  -only-testing:KlarityAppTests/SetupViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the setup types do not exist.

- [ ] **Step 3: Implement stable helper installation and executable detection**

```swift
// Sources/KlarityCore/Integrations/HelperInstaller.swift
import Foundation

public protocol HelperInstalling {
    var destinationURL: URL { get }
    func install() throws
    func isCurrent() -> Bool
}

public final class HelperInstaller: HelperInstalling {
    public let sourceURL: URL
    public let destinationURL: URL
    private let fileManager: FileManager

    public init(
        sourceURL: URL,
        destinationURL: URL,
        fileManager: FileManager = .default
    ) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.fileManager = fileManager
    }

    public static var defaultDestination: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/Klarity/bin/klarity-event"
            )
    }

    public func install() throws {
        let directory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let temporary = directory.appendingPathComponent(".klarity-event.\(UUID().uuidString)")
        try fileManager.copyItem(at: sourceURL, to: temporary)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destinationURL)
        }
    }

    public func isCurrent() -> Bool {
        guard let source = try? Data(contentsOf: sourceURL),
              let installed = try? Data(contentsOf: destinationURL) else { return false }
        return source == installed
    }
}
```

```swift
// Sources/KlarityCore/Integrations/ExecutableLocator.swift
import Foundation

public enum ExecutableLocator {
    public static func locate(_ name: String) -> URL? {
        guard ["codex", "claude"].contains(name) else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "\(home)/.local/bin/\(name)",
            "\(home)/bin/\(name)"
        ]
        if let direct = candidates
            .map(URL.init(fileURLWithPath:))
            .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return direct
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lic", "command -v \(name)"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let path = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0,
              FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
```

- [ ] **Step 4: Implement provider version detection**

```swift
// Sources/KlarityCore/Integrations/ProviderVersionDetector.swift
import Foundation

public enum ProviderVersionDetector {
    public static func detect(executableURL: URL) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = output
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let text = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return parseVersion(text)
    }

    public static func parseVersion(_ text: String) -> String? {
        text.split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .first { token in
                token.first?.isNumber == true
                    && token.split(separator: ".").count >= 2
            }?
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
    }
}
```

- [ ] **Step 5: Implement synthetic event verification**

```swift
// Sources/KlarityApp/Services/SyntheticEventService.swift
import Foundation
import KlarityCore

protocol SyntheticEventTesting {
    func run(provider: AgentProvider, helperURL: URL) throws -> Bool
}

struct SyntheticEventService: SyntheticEventTesting {
    let store: SessionStateStoring

    func run(provider: AgentProvider, helperURL: URL) throws -> Bool {
        let sessionID = "klarity-setup-\(UUID().uuidString)"
        let payload = try JSONSerialization.data(withJSONObject: [
            "session_id": sessionID,
            "turn_id": "setup",
            "cwd": FileManager.default.homeDirectoryForCurrentUser.path
        ])
        let process = Process()
        let input = Pipe()
        process.executableURL = helperURL
        process.arguments = [provider.rawValue, HookEventKind.userPromptSubmit.rawValue, "--klarity-hook"]
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        try input.fileHandleForWriting.write(contentsOf: payload)
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        let key = SessionKey(provider: provider, sessionID: sessionID)
        defer { try? store.remove(key) }
        return process.terminationStatus == 0 && (try store.load(key)) != nil
    }
}
```

- [ ] **Step 6: Implement setup state and view**

```swift
// Sources/KlarityApp/Setup/SetupViewModel.swift
import Foundation
import Observation
import KlarityCore

enum SetupPhase: Equatable {
    case unavailable
    case ready
    case installing
    case needsTrust
    case installed
    case failed(String)
}

@MainActor
@Observable
final class SetupViewModel {
    let provider: AgentProvider
    let executableURL: URL?
    let detectedVersion: String?
    private let helperInstaller: HelperInstalling
    private let integration: ProviderIntegrationManaging
    private let syntheticEventService: SyntheticEventTesting
    private let lastEvent: () -> Date?
    var phase: SetupPhase
    var integrationStatus: IntegrationStatus?
    var lastEventAt: Date?

    init(
        provider: AgentProvider,
        executableURL: URL?,
        helperInstaller: HelperInstalling,
        integration: ProviderIntegrationManaging,
        syntheticEventService: SyntheticEventTesting,
        lastEvent: @escaping () -> Date? = { nil }
    ) {
        self.provider = provider
        self.executableURL = executableURL
        self.detectedVersion = executableURL.flatMap(ProviderVersionDetector.detect)
        self.helperInstaller = helperInstaller
        self.integration = integration
        self.syntheticEventService = syntheticEventService
        self.lastEvent = lastEvent
        self.phase = executableURL == nil ? .unavailable : .ready
    }

    func install() async {
        phase = .installing
        do {
            try helperInstaller.install()
            try integration.install()
            guard try syntheticEventService.run(
                provider: provider,
                helperURL: helperInstaller.destinationURL
            ) else {
                phase = .failed("Klarity did not receive the local test event.")
                return
            }
            phase = provider == .codex ? .needsTrust : .installed
            refreshDiagnostics()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func repair() async {
        phase = .installing
        do {
            try helperInstaller.install()
            try integration.repair()
            phase = provider == .codex ? .needsTrust : .installed
            refreshDiagnostics()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func remove() {
        do {
            try integration.remove()
            phase = executableURL == nil ? .unavailable : .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func refreshDiagnostics() {
        integrationStatus = try? integration.status()
        lastEventAt = lastEvent()
    }
}
```

```swift
// Sources/KlarityApp/Setup/SetupView.swift
import SwiftUI
import KlarityCore

struct SetupView: View {
    @Bindable var claude: SetupViewModel
    @Bindable var codex: SetupViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set up Klarity").font(.largeTitle.bold())
            Text("Klarity stores local status metadata only. It never stores prompts, responses, commands, or tool arguments.")
                .foregroundStyle(.secondary)
            integrationCard("Codex", model: codex)
            integrationCard("Claude", model: claude)
            Text("Codex requires one final step: open Codex, run /hooks, review the Klarity entries, and choose Trust.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done", action: onComplete)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isConfigured)
            }
        }
        .padding(24)
        .frame(minWidth: 520)
    }

    private func integrationCard(_ title: String, model: SetupViewModel) -> some View {
        GroupBox(title) {
            HStack {
                Text(model.detectedVersion.map { "\(statusText(model.phase)) · \($0)" } ?? statusText(model.phase))
                if let lastEventAt = model.lastEventAt {
                    Text("Last event \(lastEventAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Install \(title)") { Task { await model.install() } }
                    .disabled(model.phase == .unavailable || model.phase == .installing)
                Button("Repair \(title)") { Task { await model.repair() } }
                Button("Remove \(title)") { model.remove() }
            }
            .padding(8)
        }
    }

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

    private var isConfigured: Bool {
        [claude.phase, codex.phase].contains(.installed)
            || [claude.phase, codex.phase].contains(.needsTrust)
    }
}
```

- [ ] **Step 7: Implement launch at login**

```swift
// Sources/KlarityApp/Services/LaunchAtLoginService.swift
import ServiceManagement

protocol LaunchAtLoginServicing {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct LaunchAtLoginService: LaunchAtLoginServicing {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

- [ ] **Step 8: Wire first launch into the app**

```swift
@main
struct KlarityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            appDelegate.makeSettingsView()
        }
    }
}
```

In `AppDelegate.applicationDidFinishLaunching`, call `showSetupWindow()` when:

```swift
!UserDefaults.standard.bool(forKey: "completedSetup")
```

Create a retained `NSWindow` using:

```swift
private var setupWindow: NSWindow?

private func showSetupWindow() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = "Klarity Setup"
    window.center()
    window.contentViewController = NSHostingController(rootView: makeSetupView {
        UserDefaults.standard.set(true, forKey: "completedSetup")
        self.setupWindow?.close()
        self.setupWindow = nil
    })
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    setupWindow = window
}
```

Replace Task 7's empty integration closure with:

```swift
statusItemController = StatusItemController(
    model: model,
    openIntegrations: { [weak self] in self?.showSetupWindow() }
)
```

`AppDelegate.makeSetupView` constructs both provider models using:

```swift
let helperSource = Bundle.main.url(
    forResource: "klarity-event",
    withExtension: nil,
    subdirectory: "bin"
)!
let helperInstaller = HelperInstaller(
    sourceURL: helperSource,
    destinationURL: HelperInstaller.defaultDestination
)
```

Claude settings path:

```swift
FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/settings.json")
```

Codex hooks path:

```swift
FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".codex/hooks.json")
```

At the start of `applicationDidFinishLaunching`, support a noninteractive clean-removal mode:

```swift
if CommandLine.arguments.contains("--remove-integrations") {
    try? ClaudeIntegrationManager(
        settingsURL: claudeSettingsURL,
        helperURL: HelperInstaller.defaultDestination
    ).remove()
    try? CodexIntegrationManager(
        hooksURL: codexHooksURL,
        helperURL: HelperInstaller.defaultDestination
    ).remove()
    try? FileManager.default.removeItem(
        at: HelperInstaller.defaultDestination.deletingLastPathComponent()
    )
    NSApp.terminate(nil)
    return
}
```

This mode removes only Klarity-marked hooks and Klarity-owned helper files.

- [ ] **Step 9: Run setup tests and a clean-home smoke test**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/HelperInstallerTests \
  -only-testing:KlarityAppTests/SetupViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Then launch with isolated app defaults:

```bash
defaults delete com.twodamax.klarity 2>/dev/null || true
open "$HOME/Library/Developer/Xcode/DerivedData/Klarity-"*/Build/Products/Debug/Klarity.app
```

Expected: tests PASS and the setup window appears without modifying integrations until an Install button is selected.

- [ ] **Step 10: Commit**

```bash
git add Sources/KlarityCore/Integrations Sources/KlarityApp Tests
git commit -m "feat: add safe first-launch integration setup"
```

---

### Task 10: Add preferences, opt-in updates, diagnostics, branding, and accessibility

**Files:**
- Create: `Sources/KlarityCore/Updates/UpdateChecker.swift`
- Create: `Sources/KlarityCore/Logging/DiagnosticLogger.swift`
- Create: `Sources/KlarityApp/Settings/SettingsView.swift`
- Create: `Sources/KlarityApp/Settings/PreferencesStore.swift`
- Create: `Sources/KlarityApp/Settings/UpdateViewModel.swift`
- Modify: `Sources/KlarityApp/MenuBar/StatusItemController.swift`
- Modify: `Sources/KlarityApp/MenuBar/SessionRowView.swift`
- Create: `Sources/KlarityApp/UITesting/UITestSessionStore.swift`
- Create: `Design/KlarityIcon-1024.png`
- Create: `Sources/KlarityApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Tests/KlarityCoreTests/UpdateCheckerTests.swift`
- Create: `Tests/KlarityCoreTests/DiagnosticLoggerTests.swift`
- Create: `Tests/KlarityUITests/KlarityUITests.swift`

**Interfaces:**
- Produces: `UpdateChecking`, `GitHubUpdateChecker`, `DiagnosticLogging`, `DiagnosticLogger`, `PreferencesStore`, `UpdateViewModel`, and complete accessibility identifiers.
- Consumes: app model, GitHub Releases endpoint, and macOS accessibility settings.

- [ ] **Step 1: Write failing opt-in update and sanitized logging tests**

```swift
// Tests/KlarityCoreTests/UpdateCheckerTests.swift
import XCTest
@testable import KlarityCore

final class UpdateCheckerTests: XCTestCase {
    func testDisabledAutomaticCheckDoesNotStartNetworkRequest() async throws {
        let transport = RecordingUpdateTransport(response: .init(tagName: "v9.9.9", htmlURL: URL(string: "https://example.com")!))
        let checker = GitHubUpdateChecker(transport: transport)
        let result = try await checker.check(currentVersion: "0.1.0", enabled: false)
        XCTAssertNil(result)
        XCTAssertEqual(transport.requestCount, 0)
    }

    func testNewerSemanticVersionReturnsRelease() async throws {
        let transport = RecordingUpdateTransport(response: .init(tagName: "v0.2.0", htmlURL: URL(string: "https://example.com")!))
        let checker = GitHubUpdateChecker(transport: transport)
        let result = try await checker.check(currentVersion: "0.1.0", enabled: true)
        XCTAssertEqual(result?.version, "0.2.0")
    }
}

private final class RecordingUpdateTransport: UpdateTransporting {
    let response: ReleaseMetadata
    private(set) var requestCount = 0

    init(response: ReleaseMetadata) {
        self.response = response
    }

    func latestRelease() async throws -> ReleaseMetadata {
        requestCount += 1
        return response
    }
}
```

```swift
// Tests/KlarityCoreTests/DiagnosticLoggerTests.swift
import XCTest
@testable import KlarityCore

final class DiagnosticLoggerTests: XCTestCase {
    func testLoggerWritesOnlyApprovedMetadataWhenEnabled() throws {
        let url = temporaryDirectory().appendingPathComponent("klarity.log")
        let logger = DiagnosticLogger(enabled: true, url: url)
        logger.record(
            provider: .codex,
            event: .preToolUse,
            sessionID: "session",
            result: "normalized",
            rawPayload: "SECRET_COMMAND"
        )
        let text = try String(contentsOf: url)
        XCTAssertTrue(text.contains("normalized"))
        XCTAssertFalse(text.contains("SECRET_COMMAND"))
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/UpdateCheckerTests \
  -only-testing:KlarityCoreTests/DiagnosticLoggerTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because update and logging types do not exist.

- [ ] **Step 3: Implement the opt-in GitHub release checker**

```swift
// Sources/KlarityCore/Updates/UpdateChecker.swift
import Foundation

public struct ReleaseMetadata: Codable, Equatable, Sendable {
    public let tagName: String
    public let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

public struct AvailableUpdate: Equatable, Sendable {
    public let version: String
    public let url: URL
}

public protocol UpdateTransporting {
    func latestRelease() async throws -> ReleaseMetadata
}

public protocol UpdateChecking {
    func check(currentVersion: String, enabled: Bool) async throws -> AvailableUpdate?
}

public struct GitHubReleaseTransport: UpdateTransporting {
    public init() {}

    public func latestRelease() async throws -> ReleaseMetadata {
        let url = URL(string: "https://api.github.com/repos/jwright0180/Klarity/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("Klarity", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ReleaseMetadata.self, from: data)
    }
}

public struct GitHubUpdateChecker: UpdateChecking {
    private let transport: UpdateTransporting

    public init(transport: UpdateTransporting = GitHubReleaseTransport()) {
        self.transport = transport
    }

    public func check(currentVersion: String, enabled: Bool) async throws -> AvailableUpdate? {
        guard enabled else { return nil }
        let release = try await transport.latestRelease()
        let remote = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        guard remote.compare(currentVersion, options: .numeric) == .orderedDescending else {
            return nil
        }
        return AvailableUpdate(version: remote, url: release.htmlURL)
    }
}
```

- [ ] **Step 4: Implement sanitized diagnostics and preferences**

```swift
// Sources/KlarityCore/Logging/DiagnosticLogger.swift
import Foundation

public protocol DiagnosticLogging {
    func record(
        provider: AgentProvider,
        event: HookEventKind,
        sessionID: String,
        result: String,
        rawPayload: String?
    )
}

public final class DiagnosticLogger: DiagnosticLogging {
    private let enabled: Bool
    private let url: URL
    private let lock = NSLock()

    public init(enabled: Bool, url: URL) {
        self.enabled = enabled
        self.url = url
    }

    public func record(
        provider: AgentProvider,
        event: HookEventKind,
        sessionID: String,
        result: String,
        rawPayload: String? = nil
    ) {
        guard enabled else { return }
        let line = "\(ISO8601DateFormatter().string(from: Date())) provider=\(provider.rawValue) event=\(event.rawValue) session=\(sessionID) result=\(result)\n"
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        }
        _ = rawPayload
    }
}
```

Modify `KlarityEventCommand` to accept:

```swift
private let logger: DiagnosticLogging?

public init(
    store: SessionStateStoring,
    processIdentity: @escaping (AgentProvider, [String: String]) -> ProcessIdentity?,
    logger: DiagnosticLogging? = nil
) {
    self.store = store
    self.processIdentity = processIdentity
    self.logger = logger
}
```

After a successful write:

```swift
logger?.record(
    provider: provider,
    event: event,
    sessionID: normalized.sessionID,
    result: "written",
    rawPayload: nil
)
```

In the catch block, record only the error type:

```swift
logger?.record(
    provider: provider,
    event: event,
    sessionID: payload["session_id"] as? String ?? "unknown",
    result: "failed:\(String(describing: type(of: error)))",
    rawPayload: nil
)
```

Construct the logger in `main.swift` from:

```swift
let sharedDefaults = UserDefaults(suiteName: ProductMetadata.bundleIdentifier)!
let logger: DiagnosticLogging? = sharedDefaults.bool(forKey: "diagnosticsEnabled")
    ? DiagnosticLogger(
        enabled: true,
        url: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Klarity/klarity.log")
      )
    : nil
```

Pass `logger` into `KlarityEventCommand`.

```swift
// Sources/KlarityApp/Settings/PreferencesStore.swift
import Foundation
import Observation

@MainActor
@Observable
final class PreferencesStore {
    private let defaults: UserDefaults

    var showTimer: Bool {
        didSet { defaults.set(showTimer, forKey: "showTimer") }
    }
    var automaticUpdateChecks: Bool {
        didSet { defaults.set(automaticUpdateChecks, forKey: "automaticUpdateChecks") }
    }
    var diagnosticsEnabled: Bool {
        didSet { defaults.set(diagnosticsEnabled, forKey: "diagnosticsEnabled") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showTimer = defaults.bool(forKey: "showTimer")
        self.automaticUpdateChecks = defaults.bool(forKey: "automaticUpdateChecks")
        self.diagnosticsEnabled = defaults.bool(forKey: "diagnosticsEnabled")
    }
}
```

- [ ] **Step 5: Implement manual and opt-in automatic update behavior**

```swift
// Sources/KlarityApp/Settings/UpdateViewModel.swift
import AppKit
import Foundation
import Observation
import KlarityCore

@MainActor
@Observable
final class UpdateViewModel {
    private let checker: UpdateChecking
    private let defaults: UserDefaults
    var status = "Not checked"
    var availableUpdate: AvailableUpdate?

    init(
        checker: UpdateChecking = GitHubUpdateChecker(),
        defaults: UserDefaults = .standard
    ) {
        self.checker = checker
        self.defaults = defaults
    }

    func check(manual: Bool, automaticEnabled: Bool) async {
        let now = Date()
        let last = defaults.object(forKey: "lastUpdateCheck") as? Date
        if !manual {
            guard automaticEnabled else { return }
            if let last, now.timeIntervalSince(last) < 86_400 { return }
        }

        do {
            let version = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "0.0.0"
            availableUpdate = try await checker.check(
                currentVersion: version,
                enabled: true
            )
            defaults.set(now, forKey: "lastUpdateCheck")
            status = availableUpdate.map { "Version \($0.version) is available" }
                ?? "Klarity is up to date"
        } catch {
            status = manual ? "Could not check for updates" : "Not checked"
        }
    }

    func openAvailableUpdate() {
        guard let url = availableUpdate?.url else { return }
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 6: Add settings and accessibility behavior**

```swift
// Sources/KlarityApp/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    @Bindable var updates: UpdateViewModel
    let launchAtLogin: LaunchAtLoginServicing
    @State private var launchAtLoginEnabled: Bool

    init(
        preferences: PreferencesStore,
        updates: UpdateViewModel,
        launchAtLogin: LaunchAtLoginServicing
    ) {
        self.preferences = preferences
        self.updates = updates
        self.launchAtLogin = launchAtLogin
        _launchAtLoginEnabled = State(initialValue: launchAtLogin.isEnabled)
    }

    var body: some View {
        Form {
            Toggle("Show elapsed turn timer", isOn: $preferences.showTimer)
            Toggle("Check GitHub for updates automatically", isOn: $preferences.automaticUpdateChecks)
            Toggle("Enable sanitized local diagnostics", isOn: $preferences.diagnosticsEnabled)
            HStack {
                Button("Check for Updates") {
                    Task {
                        await updates.check(
                            manual: true,
                            automaticEnabled: preferences.automaticUpdateChecks
                        )
                    }
                }
                Text(updates.status).foregroundStyle(.secondary)
                if updates.availableUpdate != nil {
                    Button("Open Release", action: updates.openAvailableUpdate)
                }
            }
            Toggle("Launch Klarity at login", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { value in
                    do {
                        try launchAtLogin.setEnabled(value)
                        launchAtLoginEnabled = value
                    } catch {
                        launchAtLoginEnabled = launchAtLogin.isEnabled
                    }
                }
            ))
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520)
    }
}
```

In `AppModel`, set:

```swift
reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
showTimer = UserDefaults(
    suiteName: ProductMetadata.bundleIdentifier
)?.bool(forKey: "showTimer") ?? false
```

Observe `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` and update the value. Ensure timer text has:

```swift
.accessibilityHidden(true)
```

so VoiceOver does not announce every timer tick. The row's static accessibility label must omit changing elapsed time.

After constructing `PreferencesStore` and `UpdateViewModel` in `AppDelegate`, call this once at launch:

```swift
Task {
    await updateViewModel.check(
        manual: false,
        automaticEnabled: preferences.automaticUpdateChecks
    )
}
```

- [ ] **Step 7: Create the app icon and asset catalog**

Invoke `$imagegen` with this exact prompt during implementation:

```text
Create a 1024 by 1024 macOS application icon for Klarity, a local AI coding-agent status monitor. Use an original neutral radial signal symbol formed from one clear central point and four balanced outward rays. Avoid OpenAI, Anthropic, Claude, Codex, chatbot, robot, brain, letter K, and copied brand shapes. Use a deep graphite background with a restrained cyan-to-mint signal glow, strong silhouette, large simple geometry, no text, no transparency, and enough contrast to remain recognizable at 16 pixels. Modern native macOS utility quality.
```

Save the approved image at `Design/KlarityIcon-1024.png`. Generate the `.appiconset` sizes with `sips`, write a complete `Contents.json`, and add `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` to `project.yml`.

Verify:

```bash
test "$(sips -g pixelWidth Design/KlarityIcon-1024.png | awk '/pixelWidth/ {print $2}')" = "1024"
test "$(sips -g pixelHeight Design/KlarityIcon-1024.png | awk '/pixelHeight/ {print $2}')" = "1024"
```

Expected: both checks exit `0`.

- [ ] **Step 8: Add deterministic UI-test fixtures and XCUITests**

When launched with:

```text
--ui-test-fixture permission
```

`AppDelegate` must write two temporary in-memory sessions instead of reading the user's state directory. Add:

```swift
enum UITestFixtureFactory {
    static func events(arguments: [String]) -> [NormalizedEvent]? {
        guard let index = arguments.firstIndex(of: "--ui-test-fixture"),
              arguments.indices.contains(index + 1) else { return nil }
        switch arguments[index + 1] {
        case "empty":
            return []
        case "permission":
            return [
                .init(
                    schemaVersion: 1,
                    provider: .claude,
                    surface: .desktop,
                    sessionID: "ui-permission",
                    turnID: "turn",
                    phase: .permission,
                    label: "Awaiting permission",
                    toolCategory: nil,
                    projectName: "Example",
                    workingDirectory: "/tmp/Example",
                    sourceBundleID: "com.anthropic.claudefordesktop",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                ),
                .init(
                    schemaVersion: 1,
                    provider: .codex,
                    surface: .cli,
                    sessionID: "ui-working",
                    turnID: "turn",
                    phase: .thinking,
                    label: "Thinking",
                    toolCategory: nil,
                    projectName: "Klarity",
                    workingDirectory: "/tmp/Klarity",
                    sourceBundleID: "com.apple.Terminal",
                    sourceProcessID: nil,
                    sourceProcessStartedAt: nil,
                    turnStartedAt: Date(),
                    updatedAt: Date()
                )
            ]
        default:
            return nil
        }
    }
}

final class UITestSessionStore: SessionStateStoring {
    private var events: [NormalizedEvent]

    init(events: [NormalizedEvent]) {
        self.events = events
    }

    func write(_ event: NormalizedEvent) {
        events.removeAll { SessionKey($0) == SessionKey(event) }
        events.append(event)
    }

    func loadAll() -> [NormalizedEvent] { events }
    func load(_ key: SessionKey) -> NormalizedEvent? {
        events.first { SessionKey($0) == key }
    }
    func remove(_ key: SessionKey) {
        events.removeAll { SessionKey($0) == key }
    }
}
```

When this returns a non-`nil` value, create the app model with `UITestSessionStore` and do not read or modify user configuration.

Add:

```swift
// Tests/KlarityUITests/KlarityUITests.swift
import XCTest

final class KlarityUITests: XCTestCase {
    func testPermissionSessionAppearsFirstAndIsAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "permission"]
        app.launch()

        let statusItem = app.statusItems["Klarity.StatusItem"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        XCTAssertTrue(app.staticTexts["Klarity.SessionSummary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Example, Awaiting permission, Desktop"].exists)
    }

    func testEmptyStateExplainsHowToStart() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "empty"]
        app.launch()
        app.statusItems["Klarity.StatusItem"].click()
        XCTAssertTrue(app.staticTexts["No active sessions"].exists)
    }

    func testSetupRepairChangesIntegrationState() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "setup-repair"]
        app.launch()

        let repair = app.buttons["Repair Codex"]
        XCTAssertTrue(repair.waitForExistence(timeout: 5))
        repair.click()
        XCTAssertTrue(app.staticTexts["Installed, trust required"].waitForExistence(timeout: 3))
    }
}
```

For `--ui-test-fixture setup-repair`, `AppDelegate` must show `SetupView` with in-memory provider managers. The Codex manager starts in a repair-needed state and changes to installed after `repair()` without touching `~/.codex` or `~/.claude`.

- [ ] **Step 9: Run unit and UI tests**

```bash
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityCoreTests/UpdateCheckerTests \
  -only-testing:KlarityCoreTests/DiagnosticLoggerTests
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -only-testing:KlarityUITests
```

Expected: update, logging, permission-state, and empty-state tests PASS.

- [ ] **Step 10: Commit**

```bash
git add Sources Design Tests project.yml
git commit -m "feat: add preferences updates branding and accessibility"
```

---

### Task 11: Add privacy documentation, attribution, CI, and release gates

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `docs/privacy.md`
- Create: `docs/integrations.md`
- Create: `docs/release-checklist.md`
- Create: `Scripts/verify-privacy.sh`
- Create: `Scripts/verify-release-gates.sh`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: documented privacy contract, contributor onboarding, CI, and enforceable local release gates.
- Consumes: exact schema and supported-event lists from prior tasks.

- [ ] **Step 1: Write failing privacy verification script**

```bash
#!/usr/bin/env bash
# Scripts/verify-privacy.sh
set -euo pipefail

schema="Sources/KlarityCore/Events/NormalizedEvent.swift"
privacy="docs/privacy.md"

required_fields=(
  schemaVersion provider surface sessionID turnID phase label toolCategory
  projectName workingDirectory sourceBundleID sourceProcessID
  sourceProcessStartedAt turnStartedAt updatedAt
)

for field in "${required_fields[@]}"; do
  rg -q "\\b${field}\\b" "$schema"
  rg -q "\\b${field}\\b" "$privacy"
done

for forbidden in prompt assistantMessage command toolInput toolResponse transcriptContents; do
  if rg -q "public let ${forbidden}|public var ${forbidden}" "$schema"; then
    echo "Forbidden stored field: ${forbidden}" >&2
    exit 1
  fi
done
```

Run:

```bash
chmod +x Scripts/verify-privacy.sh
Scripts/verify-privacy.sh
```

Expected: FAIL because `docs/privacy.md` does not exist.

- [ ] **Step 2: Write the exact privacy contract**

`docs/privacy.md` must state:

```markdown
# Klarity Privacy

Klarity runs locally on your Mac. It has no account system, backend, analytics,
telemetry, advertising, cloud sync, remote monitoring, or uploaded crash reports.

## Stored session fields

- `schemaVersion`
- `provider`
- `surface`
- `sessionID`
- `turnID`
- `phase`
- `label`
- `toolCategory`
- `projectName`
- `workingDirectory`
- `sourceBundleID`
- `sourceProcessID`
- `sourceProcessStartedAt`
- `turnStartedAt`
- `updatedAt`

Klarity does not store prompts, responses, assistant messages, commands, tool
arguments, tool responses, transcript contents, or file contents.

## Network requests

Klarity makes no network request by default. A manual update check, or an
automatic update check explicitly enabled by the user, requests only the latest
release metadata from GitHub's public Releases API.
```

- [ ] **Step 3: Add README, integration guide, MIT license, and attribution**

The README must include:

- One-sentence product value.
- Supported macOS version and architectures.
- Supported Codex and Claude surfaces.
- DMG and Homebrew installation.
- Setup and Codex `/hooks` trust instructions.
- Local-only privacy summary.
- Build commands: `xcodegen generate` and the exact `xcodebuild test` command.
- A clear attribution sentence:

```text
Klarity is an independent implementation inspired by Mick Cesanek's MIT-licensed Claude Status Bar project. Klarity does not reuse that project's source code or branding.
```

The integration guide must list every installed event, config path, backup filename, repair behavior, and removal behavior.

Use the standard MIT license text with:

```text
Copyright (c) 2026 Klarity contributors
```

- [ ] **Step 4: Add enforceable name and publication gates**

```bash
#!/usr/bin/env bash
# Scripts/verify-release-gates.sh
set -euo pipefail

required=(
  KLARITY_NAME_CLEARED
  KLARITY_RELEASE_BUILD_APPROVED
  DEVELOPER_ID_APPLICATION
  NOTARY_PROFILE
)

for variable in "${required[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing release gate: ${variable}" >&2
    exit 1
  fi
done

[[ "$KLARITY_NAME_CLEARED" == "1" ]]
[[ "$KLARITY_RELEASE_BUILD_APPROVED" == "1" ]]
```

`docs/release-checklist.md` must require dated evidence for:

- Trademark and marketplace search.
- GitHub repository and organization availability.
- Homebrew token availability.
- Domain and social-handle decision.
- User approval to publish.
- Developer ID signing identity.
- Notary profile.
- Privacy review.
- Accessibility review.
- DMG and Cask verification.

- [ ] **Step 5: Add macOS CI**

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate project
        run: xcodegen generate
      - name: Test
        run: |
          xcodebuild test \
            -project Klarity.xcodeproj \
            -scheme Klarity \
            -destination 'platform=macOS' \
            -skip-testing:KlarityUITests \
            CODE_SIGNING_ALLOWED=NO
      - name: Verify privacy contract
        run: Scripts/verify-privacy.sh
```

- [ ] **Step 6: Run documentation and CI-equivalent checks**

```bash
Scripts/verify-privacy.sh
bash -n Scripts/verify-release-gates.sh
xcodegen generate
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS' \
  -skip-testing:KlarityUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: privacy verification and tests PASS. `verify-release-gates.sh` is syntax-checked but not executed because public release is not approved yet.

- [ ] **Step 7: Commit**

```bash
git add README.md LICENSE docs Scripts .github
git commit -m "docs: define privacy integrations and release gates"
```

---

### Task 12: Build, sign, notarize, package, and verify the universal release

**Files:**
- Create: `Scripts/build-release.sh`
- Create: `Scripts/create-dmg.sh`
- Create: `Scripts/verify-release.sh`
- Create: `Scripts/generate-cask.sh`
- Create: `Cask/klarity.rb`
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Produces: `build/Klarity.app`, `build/Klarity-<version>.dmg`, verified signatures, notarization tickets, and a generated Homebrew Cask.
- Consumes: `DEVELOPER_ID_APPLICATION`, `NOTARY_PROFILE`, `KLARITY_NAME_CLEARED=1`, and `KLARITY_RELEASE_BUILD_APPROVED=1`.

- [ ] **Step 1: Write failing release-script syntax and gate checks**

Create empty executable script files, then run:

```bash
chmod +x Scripts/build-release.sh Scripts/create-dmg.sh Scripts/verify-release.sh Scripts/generate-cask.sh
bash -n Scripts/build-release.sh
bash -n Scripts/create-dmg.sh
bash -n Scripts/verify-release.sh
bash -n Scripts/generate-cask.sh
Scripts/verify-release-gates.sh
```

Expected: syntax checks pass and the release-gate command FAILS with `Missing release gate: KLARITY_NAME_CLEARED`.

- [ ] **Step 2: Implement universal app build and signing**

```bash
#!/usr/bin/env bash
# Scripts/build-release.sh
set -euo pipefail

version="${1:?usage: build-release.sh VERSION}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

Scripts/verify-release-gates.sh
xcodegen generate
rm -rf build/DerivedData build/Klarity.app

xcodebuild build \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$version" \
  CODE_SIGNING_ALLOWED=NO

source_app="build/DerivedData/Build/Products/Release/Klarity.app"
ditto "$source_app" build/Klarity.app

helper="build/Klarity.app/Contents/Resources/bin/klarity-event"
codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" "$helper"
codesign --force --options runtime --timestamp \
  --entitlements Config/Klarity.entitlements \
  --sign "$DEVELOPER_ID_APPLICATION" build/Klarity.app

codesign --verify --deep --strict --verbose=2 build/Klarity.app
lipo -archs build/Klarity.app/Contents/MacOS/Klarity
lipo -archs "$helper"
```

- [ ] **Step 3: Implement signed and notarized DMG creation**

```bash
#!/usr/bin/env bash
# Scripts/create-dmg.sh
set -euo pipefail

version="${1:?usage: create-dmg.sh VERSION}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

app="build/Klarity.app"
dmg="build/Klarity-${version}.dmg"
stage="build/dmg-stage"
rm -rf "$stage" "$dmg"
mkdir -p "$stage"
ditto "$app" "$stage/Klarity.app"
ln -s /Applications "$stage/Applications"

hdiutil create \
  -volname "Klarity" \
  -srcfolder "$stage" \
  -ov \
  -format UDZO \
  "$dmg"

codesign --force --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" "$dmg"
xcrun notarytool submit "$dmg" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
rm -rf "$stage"
```

- [ ] **Step 4: Implement release verification**

```bash
#!/usr/bin/env bash
# Scripts/verify-release.sh
set -euo pipefail

version="${1:?usage: verify-release.sh VERSION}"
app="build/Klarity.app"
dmg="build/Klarity-${version}.dmg"
helper="$app/Contents/Resources/bin/klarity-event"

test -d "$app"
test -f "$dmg"
test -x "$helper"

[[ "$(lipo -archs "$app/Contents/MacOS/Klarity")" == *arm64* ]]
[[ "$(lipo -archs "$app/Contents/MacOS/Klarity")" == *x86_64* ]]
[[ "$(lipo -archs "$helper")" == *arm64* ]]
[[ "$(lipo -archs "$helper")" == *x86_64* ]]

codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute --verbose=2 "$app"
xcrun stapler validate "$dmg"
Scripts/verify-privacy.sh

mount="$(hdiutil attach -nobrowse -readonly "$dmg" | awk '/Volumes/ {print $3; exit}')"
trap 'hdiutil detach "$mount" >/dev/null' EXIT
test -d "$mount/Klarity.app"
test -L "$mount/Applications"
```

- [ ] **Step 5: Implement deterministic Cask generation**

```bash
#!/usr/bin/env bash
# Scripts/generate-cask.sh
set -euo pipefail

version="${1:?usage: generate-cask.sh VERSION DMG}"
dmg="${2:?usage: generate-cask.sh VERSION DMG}"
sha="$(shasum -a 256 "$dmg" | awk '{print $1}')"

cat > Cask/klarity.rb <<RUBY
cask "klarity" do
  version "${version}"
  sha256 "${sha}"

  url "https://github.com/jwright0180/Klarity/releases/download/v#{version}/Klarity-#{version}.dmg"
  name "Klarity"
  desc "Local Codex and Claude session status for the macOS menu bar"
  homepage "https://github.com/jwright0180/Klarity"

  depends_on macos: ">= :sonoma"
  app "Klarity.app"

  uninstall quit: "com.twodamax.klarity",
            script: {
              executable: "#{appdir}/Klarity.app/Contents/MacOS/Klarity",
              args: ["--remove-integrations"],
              sudo: false,
            }

  zap trash: [
    "~/Library/Application Support/Klarity",
    "~/Library/Preferences/com.twodamax.klarity.plist",
  ]
end
RUBY
```

- [ ] **Step 6: Add a manual release workflow without enabling publication**

```yaml
# .github/workflows/release.yml
name: Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: Version without the v prefix
        required: true

jobs:
  package:
    if: ${{ vars.KLARITY_PUBLICATION_APPROVED == '1' }}
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: brew install xcodegen
      - name: Import signing certificate
        run: echo "Enable only after publication approval and secret configuration."
      - name: Build
        run: Scripts/build-release.sh "${{ inputs.version }}"
      - name: Package
        run: Scripts/create-dmg.sh "${{ inputs.version }}"
      - name: Verify
        run: Scripts/verify-release.sh "${{ inputs.version }}"
```

The repository variable `KLARITY_PUBLICATION_APPROVED` must remain unset until explicit publication approval, signing-secret configuration, and review of the exact release workflow.

- [ ] **Step 7: Run unsigned local packaging preflight**

Before signing credentials are used, verify build and script shape:

```bash
bash -n Scripts/*.sh
xcodegen generate
xcodebuild build \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -configuration Release \
  -derivedDataPath build/UnsignedDerivedData \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO
```

Expected: Release build succeeds and both app and helper contain arm64 and x86_64 slices.

- [ ] **Step 8: Run signed release verification only after credentials and approvals exist**

```bash
export KLARITY_NAME_CLEARED=1
export KLARITY_RELEASE_BUILD_APPROVED=1
export DEVELOPER_ID_APPLICATION="$(
  security find-identity -v -p codesigning |
    awk -F '"' '/Developer ID Application/ {print $2; exit}'
)"
export NOTARY_PROFILE='klarity-notary'
test -n "$DEVELOPER_ID_APPLICATION"

Scripts/build-release.sh 0.1.0
Scripts/create-dmg.sh 0.1.0
Scripts/verify-release.sh 0.1.0
Scripts/generate-cask.sh 0.1.0 build/Klarity-0.1.0.dmg
brew install --cask ./Cask/klarity.rb
open /Applications/Klarity.app
brew uninstall --cask klarity
```

Expected: every command succeeds. Do not run this step until the user has approved publication-related actions and the private signing material is configured.

- [ ] **Step 9: Commit**

```bash
git add Scripts Cask .github/workflows/release.yml
git commit -m "build: add signed DMG and Homebrew release pipeline"
```

---

### Task 13: Run the complete acceptance matrix and prepare the private release candidate

**Files:**
- Modify only files required to fix failures found by this task.
- Update: `docs/release-checklist.md`

**Interfaces:**
- Produces: a private, fully verified v0.1.0 release candidate.
- Consumes: all prior tasks.

- [ ] **Step 1: Run all automated tests**

```bash
xcodegen generate
xcodebuild test \
  -project Klarity.xcodeproj \
  -scheme Klarity \
  -destination 'platform=macOS'
Scripts/verify-privacy.sh
```

Expected: all unit, integration, app-model, and UI tests PASS.

- [ ] **Step 2: Exercise both providers with temporary isolated configs**

Build the helper, then execute every committed fixture into an isolated state directory:

```bash
xcodebuild build \
  -project Klarity.xcodeproj \
  -scheme KlarityEvent \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

helper="$HOME/Library/Developer/Xcode/DerivedData/Klarity-"*/Build/Products/Debug/klarity-event
tmp_root="$(mktemp -d)"
state_directory="$tmp_root/sessions"

run_fixture() {
  local provider="$1"
  local event="$2"
  local fixture="$3"
  KLARITY_STATE_DIRECTORY="$state_directory" \
    "$helper" "$provider" "$event" --klarity-hook < "$fixture"
}

run_fixture claude UserPromptSubmit Tests/Fixtures/claude/user-prompt-submit.json
run_fixture claude PermissionRequest Tests/Fixtures/claude/permission-request.json
run_fixture codex PreToolUse Tests/Fixtures/codex/pre-tool-use.json
run_fixture codex Stop Tests/Fixtures/codex/stop.json

test "$(find "$state_directory" -name '*.json' | wc -l | tr -d ' ')" = "2"
rg -n 'SECRET_PROMPT|SECRET_COMMAND|SECRET_PATCH|SECRET_RESPONSE' \
  "$state_directory" && exit 1 || true
```

Expected: one final valid file for the Claude session, one final valid file for the Codex session, and no prohibited decoy text.

- [ ] **Step 3: Run the live local smoke matrix**

On the development Mac:

1. Install Klarity's Claude integration.
2. Trust Klarity's Codex hooks through `/hooks`.
3. Start one Claude CLI session and one Codex CLI session.
4. Submit prompts in both.
5. Trigger read, edit, search, shell, web, and MCP tool events.
6. Trigger a permission request in each provider.
7. Complete, deny, interrupt, and force-quit turns.
8. Launch Codex Desktop and Claude Desktop Code and repeat the status checks.
9. Confirm the menu sorts permission first.
10. Confirm selecting each row activates the correct source application.
11. Confirm no permanent active state remains after interruptions or force quits.

Record each result in `docs/release-checklist.md` with date, app version, and pass or fail.

- [ ] **Step 4: Run accessibility verification**

Verify and record:

- Keyboard access to every setup and settings control.
- VoiceOver labels for status item, provider, project, status, source surface, and actions.
- No timer-tick announcements.
- Sufficient Light Mode and Dark Mode contrast.
- Visible focus rings.
- Reduced Motion removes continuous animation.
- Menu rows retain usable click targets.

- [ ] **Step 5: Build the private signed release candidate**

After name clearance, signing setup, and explicit approval:

```bash
Scripts/build-release.sh 0.1.0
Scripts/create-dmg.sh 0.1.0
Scripts/verify-release.sh 0.1.0
Scripts/generate-cask.sh 0.1.0 build/Klarity-0.1.0.dmg
```

Expected: universal, signed, notarized, stapled, Gatekeeper-approved DMG and a Cask containing its exact SHA-256.

- [ ] **Step 6: Review the final diff and commit verification evidence**

```bash
git status --short
git diff --check
git diff --stat
git add docs/release-checklist.md
git commit -m "test: verify Klarity v0.1.0 release candidate"
```

Expected: only intentional verification evidence and required failure fixes are committed.

- [ ] **Step 7: Stop before external publication**

Report:

- Test results.
- Live provider matrix.
- Accessibility results.
- DMG path and SHA-256.
- Cask path.
- Remaining name-clearance or signing blockers.

Do not create a public repository, GitHub release, Homebrew submission, website, or announcement without a new explicit approval.
