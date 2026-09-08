import XCTest
@testable import AgenticGlowCore

/// Adversarial input and scale probes for the pure Core layer.
///
/// These assert the properties the product needs to hold when a hook
/// payload, a cached file, or a provider response is hostile, corrupt, or
/// merely enormous. A failure here is a finding, not a flaky test.
final class StressTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Untrusted hook payload boundary

    /// `label` is user-facing popover copy fed by an external hook process.
    func testValidateRejectsUnboundedLabel() throws {
        let event = event(label: String(repeating: "A", count: 1_000_000))
        XCTAssertThrowsError(try event.validate(), "a 1 MB label should not reach the UI")
    }

    func testValidateRejectsNewlinesInLabel() throws {
        let event = event(label: "Running\n\n\n\nsomething")
        XCTAssertThrowsError(try event.validate(), "a multi-line label breaks single-line copy")
    }

    /// `model` flows into compact widget and popover copy.
    func testValidateRejectsUnboundedModelSlug() throws {
        let event = event(model: String(repeating: "m", count: 100_000))
        XCTAssertThrowsError(try event.validate(), "an unbounded model slug should be rejected")
    }

    func testValidateRejectsUnboundedWorkingDirectory() throws {
        let event = event(workingDirectory: "/" + String(repeating: "d", count: 200_000))
        XCTAssertThrowsError(try event.validate(), "a 200 KB path should be rejected")
    }

    /// `projectName` rejects "\n" but the display layer is single-line for
    /// every control character, and a bidi override can reverse the name.
    func testValidateRejectsControlAndBidiCharactersInProjectName() throws {
        XCTAssertThrowsError(try event(projectName: "Repo\rInjected").validate(), "carriage return")
        XCTAssertThrowsError(try event(projectName: "Repo\u{202E}txt.evil").validate(), "bidi override")
        XCTAssertThrowsError(try event(projectName: "Repo\u{0007}bell").validate(), "control character")
    }

    /// The property that actually matters for a traversal-shaped session id:
    /// the on-disk filename must stay inside the sessions directory.
    func testSessionFilenameStaysInsideDirectory() {
        let directory = URL(fileURLWithPath: "/tmp/AgenticGlowSessions", isDirectory: true)
        for hostile in ["..", "...", ".-.", "..-..", String(repeating: ".", count: 64)] {
            let key = SessionKey(provider: .codex, sessionID: hostile)
            let resolved = directory.appendingPathComponent(key.filename).standardizedFileURL.path
            XCTAssertTrue(
                resolved.hasPrefix(directory.standardizedFileURL.path + "/"),
                "session id \(hostile) escaped the sessions directory: \(resolved)"
            )
        }
    }

    // MARK: - Title derivation

    /// A work row with an empty title is a blank line in the popover.
    func testDisplayTitleIsNeverEmptyForNonEmptyInput() {
        for raw in ["abcdef-", "-abcdef", "---", "-", "a1b2c3-", "--deadbeef--"] {
            XCTAssertFalse(
                WorkTitle.display(raw).isEmpty,
                "WorkTitle.display(\(raw)) produced an empty title"
            )
        }
    }

    func testDisplayTitleSurvivesUnicodeAndLongNames() {
        let long = String(repeating: "segment-", count: 5_000) + "end"
        XCTAssertFalse(WorkTitle.display(long).isEmpty)
        XCTAssertEqual(WorkTitle.display("café-münchen"), "Café München")
        XCTAssertEqual(WorkTitle.display("日本-プロジェクト"), "日本 プロジェクト")
    }

    // MARK: - Hostile numbers

    /// Feeds the widget bar geometry. A non-finite value here becomes a
    /// NaN frame width in SwiftUI.
    func testNormalizedProgressIsAlwaysFinite() {
        for percent in [Double.nan, .infinity, -.infinity, 1e308, -1e308, 5_000, -5_000] {
            let window = WidgetAllowanceWindow(
                provider: .claude,
                kind: .current,
                label: "5h",
                percentLeft: percent,
                resetAt: nil
            )
            let progress = try? XCTUnwrap(window.normalizedProgress)
            XCTAssertTrue(
                (progress ?? 0).isFinite,
                "normalizedProgress for \(percent) was \(String(describing: progress))"
            )
            XCTAssertTrue(
                (0...1).contains(progress ?? 0),
                "normalizedProgress for \(percent) left the 0...1 range"
            )
        }
    }

    /// The designated initializer clamps. Decoding a cache file does not go
    /// through it, so a corrupt cache can carry any value.
    func testDecodedAllowanceIsClamped() throws {
        let json = """
        {
          "provider": "claude",
          "currentWindowLabel": "5h",
          "currentPercentUsed": 5000,
          "currentPercentLeft": -4900,
          "weeklyPercentUsed": -20,
          "weeklyPercentLeft": 120,
          "fetchedAt": 1800000000
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let allowance = try decoder.decode(ProviderAllowance.self, from: Data(json.utf8))
        for value in [
            allowance.currentPercentUsed,
            allowance.currentPercentLeft,
            allowance.weeklyPercentUsed,
            allowance.weeklyPercentLeft
        ].compactMap({ $0 }) {
            XCTAssertTrue(
                (0...100).contains(value),
                "decoded percentage \(value) is outside 0...100"
            )
        }
    }

    /// Codex reports reset timestamps as raw epoch seconds. A unit slip or a
    /// garbage value must not become a Date the formatters then consume.
    func testCodexNormalizerRejectsAbsurdResetTimestamps() throws {
        for resetsAt in ["1e308", "-1e308", "18000000000000000000"] {
            let json = """
            {"result":{"rateLimits":{"primary":{"usedPercent":10,"windowDurationMins":300,"resetsAt":\(resetsAt)}}}}
            """
            let allowance = try? CodexAllowanceNormalizer.normalize(Data(json.utf8), fetchedAt: now)
            guard let allowance else { continue }
            let seconds = allowance.currentResetAt?.timeIntervalSince1970 ?? 0
            XCTAssertTrue(seconds.isFinite, "resetsAt \(resetsAt) produced a non-finite Date")
            XCTAssertLessThan(
                abs(seconds - now.timeIntervalSince1970),
                100 * 365 * 24 * 3600,
                "resetsAt \(resetsAt) produced a Date a century+ away"
            )
        }
    }

    func testCodexNormalizerClampsHostilePercentages() throws {
        let json = """
        {"result":{"rateLimits":{"primary":{"usedPercent":-999,"windowDurationMins":300,"resetsAt":1800001000}}}}
        """
        let allowance = try CodexAllowanceNormalizer.normalize(Data(json.utf8), fetchedAt: now)
        XCTAssertEqual(allowance.currentPercentUsed, 0)
        XCTAssertEqual(allowance.currentPercentLeft, 100)
    }

    // MARK: - Widget formatting extremes

    func testElapsedLabelHandlesExtremeSeconds() {
        XCTAssertNil(WidgetSnapshotFormatting.elapsedLabel(seconds: -1))
        XCTAssertNotNil(WidgetSnapshotFormatting.elapsedLabel(seconds: Int.max))
        XCTAssertEqual(WidgetSnapshotFormatting.elapsedLabel(seconds: 0), "0s")
    }

    func testLastUpdatedLabelHandlesDistantDates() {
        XCTAssertEqual(WidgetSnapshotFormatting.lastUpdatedLabel(.distantFuture, now: now), "Just now")
        XCTAssertFalse(WidgetSnapshotFormatting.lastUpdatedLabel(.distantPast, now: now).isEmpty)
    }

    // MARK: - Scale

    func testGroupingHandlesLargeSessionSet() {
        let sessions = (0..<5_000).map { index in
            session(
                id: "session-\(index)",
                provider: AgentProvider.allCases[index % AgentProvider.allCases.count],
                path: "/Volumes/Work/project-\(index % 250)"
            )
        }
        let start = Date()
        let groups = WorkGrouping.groups(from: sessions)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(groups.count, 250)
        XCTAssertEqual(groups.reduce(0) { $0 + $1.sourceReports.count }, 5_000)
        XCTAssertLessThan(elapsed, 2.0, "grouping 5,000 sessions took \(elapsed)s")
    }

    /// Every report collapsing onto one logical session in one work.
    func testGroupingHandlesPathologicalDuplicates() {
        let sessions = (0..<2_000).map { _ in
            session(id: "same", provider: .claude, path: "/Volumes/Work/One")
        }
        let groups = WorkGrouping.groups(from: sessions)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].sessions.count, 1)
        XCTAssertEqual(groups[0].sourceReports.count, 2_000)
        XCTAssertFalse(groups[0].presentation.displayName.isEmpty)
    }

    /// Compact copy is one line in a menu bar popover and a widget row. It
    /// dedupes by model name, so it stays short at realistic scale and only
    /// grows with the number of *distinct* models in one folder. Documented
    /// rather than asserted tight: 500 distinct models is not a real state.
    func testCompactStatusLineGrowsOnlyWithDistinctModels() {
        let manyDistinct = (0..<500).map { index in
            session(
                id: "s\(index)",
                provider: .claude,
                path: "/Volumes/Work/Busy",
                phase: .thinking,
                model: "claude-model-\(index)"
            )
        }
        let repeated = (0..<500).map { index in
            session(
                id: "s\(index)",
                provider: .claude,
                path: "/Volumes/Work/Busy",
                phase: .thinking,
                model: "claude-opus-4-5"
            )
        }
        let distinctLine = WorkStatusLine.compact(for: WorkGrouping.groups(from: manyDistinct)[0])
        let repeatedLine = WorkStatusLine.compact(for: WorkGrouping.groups(from: repeated)[0])

        XCTAssertLessThanOrEqual(repeatedLine.count, 80, "repeated model line: \(repeatedLine)")
        XCTAssertGreaterThan(distinctLine.count, 1_000, "distinct-model line is unbounded by design")
    }

    // MARK: - Model name copy

    /// Anthropic slugs carry the minor version as another hyphen segment,
    /// which the tokenizer turns into a separate word.
    func testHyphenatedMinorVersionReadsAsOneVersionNumber() {
        XCTAssertEqual(ModelDisplayName.display("claude-opus-4-5"), "Claude Opus 4.5")
        XCTAssertEqual(ModelDisplayName.display("claude-sonnet-4-5-thinking"), "Claude Sonnet 4.5")
    }

    func testDeeplyNestedPathsGroupAndName() {
        let deep = "/" + (0..<400).map { "level\($0)" }.joined(separator: "/")
        let groups = WorkGrouping.groups(from: [session(id: "deep", path: deep)])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].presentation.displayName, "level399")
    }

    // MARK: - Determinism

    func testGroupingIsDeterministicUnderConcurrency() {
        let sessions = (0..<300).map { index in
            session(
                id: "s\(index)",
                provider: AgentProvider.allCases[index % AgentProvider.allCases.count],
                path: "/Volumes/Work/project-\(index % 17)",
                phase: Self.phases[index % Self.phases.count]
            )
        }
        let expected = WorkGrouping.groups(from: sessions).map(\.presentation.displayName)
        let results = NSMutableArray()
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            let names = WorkGrouping.groups(from: sessions).map(\.presentation.displayName)
            lock.lock()
            results.add(names)
            lock.unlock()
        }

        for case let names as [String] in results {
            XCTAssertEqual(names, expected, "grouping was not deterministic across threads")
        }
    }

    // MARK: - Corrupt widget snapshot

    /// The widget trusts whatever decodes out of the App Group container.
    func testSnapshotSourceRejectsForeignSchemaVersion() throws {
        let directory = temporaryDirectory()
        let json = """
        {
          "schemaVersion": 99,
          "generatedAt": 1800000000,
          "sessions": [],
          "allowances": [],
          "providers": [],
          "attentionCount": -5,
          "activeCount": -5
        }
        """
        try Data(json.utf8).write(
            to: directory.appendingPathComponent(AppGroupSnapshotSource.snapshotFilename)
        )
        let source = AppGroupSnapshotSource(containerDirectory: { directory })
        let result = source.loadSnapshot()
        if case .loaded(let snapshot) = result {
            XCTFail("loaded a schemaVersion \(snapshot.schemaVersion) snapshot with negative counts")
        }
    }

    private static let phases: [SessionPhase] = [
        .idle, .thinking, .usingTool, .permission, .completed, .failed, .disconnected
    ]

    // MARK: - Helpers

    private func event(
        label: String = "Editing",
        projectName: String = "Repo",
        workingDirectory: String = "/Volumes/Work/Repo",
        model: String? = "claude-opus-4-5"
    ) -> NormalizedEvent {
        NormalizedEvent(
            schemaVersion: ProductMetadata.schemaVersion,
            provider: .claude,
            surface: .cli,
            sessionID: "abc123",
            turnID: nil,
            phase: .thinking,
            label: label,
            toolCategory: nil,
            projectName: projectName,
            workingDirectory: workingDirectory,
            sourceBundleID: nil,
            sourceProcessID: nil,
            sourceProcessStartedAt: nil,
            turnStartedAt: nil,
            updatedAt: now,
            model: model
        )
    }

    private func session(
        id: String,
        provider: AgentProvider = .claude,
        path: String,
        phase: SessionPhase = .thinking,
        model: String? = nil
    ) -> SessionSnapshot {
        SessionSnapshot(
            provider: provider,
            surface: .cli,
            sessionID: id,
            phase: phase,
            label: "Working",
            projectName: URL(fileURLWithPath: path).lastPathComponent,
            workingDirectory: path,
            sourceBundleID: nil,
            elapsedSeconds: 1,
            updatedAt: now,
            model: model
        )
    }
}
