import CloudKit
import Foundation
import XCTest
@testable import AgenticGlowCore

final class SyncedStateEnvelopeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_783_099_000)
    private let macID = "6B29FC40-CA47-1067-B31D-00DD010662DA"

    private func makeSnapshot(
        sessions: [WidgetSessionSummary]? = nil,
        allowances: [WidgetAllowanceSummary]? = nil,
        attentionCount: Int = 0,
        activeCount: Int = 1,
        schemaVersion: Int = WidgetSnapshot.currentSchemaVersion
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: schemaVersion,
            generatedAt: now,
            sessions: sessions ?? [
                WidgetSessionSummary(
                    provider: .claude, sessionID: "s1", projectName: "AgenticGlow", phase: .thinking,
                    toolCategory: nil, elapsedSeconds: 42, updatedAt: now, needsAttention: false
                )
            ],
            allowances: allowances ?? [
                WidgetAllowanceSummary(
                    provider: .codex, currentWindowLabel: "Weekly", currentPercentLeft: 19,
                    currentResetAt: now.addingTimeInterval(3600), weeklyPercentLeft: nil,
                    weeklyResetAt: nil, fetchedAt: now
                )
            ],
            providers: [WidgetProviderSummary(provider: .claude, installed: true)],
            attentionCount: attentionCount,
            activeCount: activeCount,
            revision: 3
        )
    }

    private func makeEnvelope(
        snapshot: WidgetSnapshot? = nil,
        macID: String? = nil,
        macName: String = "MacBook Pro",
        observedAt: Date? = nil,
        schemaVersion: Int = SyncedStateEnvelope.currentSchemaVersion
    ) -> SyncedStateEnvelope {
        SyncedStateEnvelope(
            schemaVersion: schemaVersion,
            sourceMacID: macID ?? self.macID,
            sourceMacName: macName,
            observedAt: observedAt ?? now,
            snapshot: snapshot ?? makeSnapshot()
        )
    }

    // MARK: Encoding

    func testRoundTripsThroughTheCodec() throws {
        let envelope = makeEnvelope()
        let data = try SyncedStateCodec.encode(envelope)
        XCTAssertEqual(try SyncedStateCodec.decode(data), envelope)
    }

    func testEncodingIsTheSharedAgenticGlowDialect() throws {
        let data = try SyncedStateCodec.encode(makeEnvelope())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["observedAt"] as? Double, now.timeIntervalSince1970)
        XCTAssertNotNil(object["snapshot"] as? [String: Any])
        // Sorted keys keep two encodings of equal values byte-identical.
        XCTAssertEqual(data, try SyncedStateCodec.encode(makeEnvelope()))
    }

    func testEncodedPayloadCarriesOnlyTheWidgetContract() throws {
        let data = try SyncedStateCodec.encode(makeEnvelope())
        let text = String(decoding: data, as: UTF8.self)
        for forbidden in ["workingDirectory", "cookie", "Cookie", "token", "authorization", "sourceProcessID"] {
            XCTAssertFalse(text.contains(forbidden), "payload must not carry \(forbidden)")
        }
    }

    // MARK: Decoding safety

    func testMalformedDataIsRejected() {
        XCTAssertThrowsError(try SyncedStateCodec.decode(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .malformed)
        }
    }

    func testOversizedPayloadIsRejectedBeforeDecoding() {
        let data = Data(repeating: 0x20, count: SyncedStateCodec.maximumPayloadBytes + 1)
        XCTAssertThrowsError(try SyncedStateCodec.decode(data)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .payloadTooLarge)
        }
    }

    func testUnknownFieldsDecodeSilently() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try SyncedStateCodec.encode(makeEnvelope())) as? [String: Any]
        )
        object["futureField"] = "ignored"
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertEqual(try SyncedStateCodec.decode(data), makeEnvelope())
    }

    func testMissingSnapshotIsMalformed() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try SyncedStateCodec.encode(makeEnvelope())) as? [String: Any]
        )
        object.removeValue(forKey: "snapshot")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try SyncedStateCodec.decode(data)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .malformed)
        }
    }

    // MARK: Validation

    func testEnvelopeSchemaMismatchIsRejected() {
        XCTAssertThrowsError(try SyncedStateValidator.validate(makeEnvelope(schemaVersion: 2), now: now)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .unsupportedEnvelopeSchema(2))
        }
    }

    func testSnapshotSchemaMismatchIsRejected() {
        let envelope = makeEnvelope(snapshot: makeSnapshot(schemaVersion: 1))
        XCTAssertThrowsError(try SyncedStateValidator.validate(envelope, now: now)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .unsupportedSnapshotSchema(1))
        }
    }

    func testMacIdentifierMustBeAUUID() {
        XCTAssertThrowsError(try SyncedStateValidator.validate(makeEnvelope(macID: "C02ABC123DEF"), now: now)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .invalidSourceMac)
        }
        XCTAssertThrowsError(try SyncedStateValidator.validate(makeEnvelope(macName: ""), now: now))
        XCTAssertThrowsError(
            try SyncedStateValidator.validate(makeEnvelope(macName: String(repeating: "x", count: 129)), now: now)
        )
    }

    func testNegativeCountsAreRejected() {
        let envelope = makeEnvelope(snapshot: makeSnapshot(attentionCount: -1))
        XCTAssertThrowsError(try SyncedStateValidator.validate(envelope, now: now)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .invalidCounts)
        }
    }

    func testMoreSessionsThanTheBuilderEverEmitsAreRejected() {
        let session = makeSnapshot().sessions[0]
        let sessions = Array(repeating: session, count: WidgetSnapshotBuilder.maximumSessions + 1)
        let envelope = makeEnvelope(snapshot: makeSnapshot(sessions: sessions))
        XCTAssertThrowsError(try SyncedStateValidator.validate(envelope, now: now)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .tooManySessions(9))
        }
    }

    func testEmptyOrOversizedSessionTextIsRejected() {
        let empty = WidgetSessionSummary(
            provider: .codex, sessionID: "", projectName: "X", phase: .idle,
            toolCategory: nil, elapsedSeconds: nil, updatedAt: now, needsAttention: false
        )
        XCTAssertThrowsError(try SyncedStateValidator.validate(makeEnvelope(snapshot: makeSnapshot(sessions: [empty])), now: now)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .invalidSession)
        }
        let long = WidgetSessionSummary(
            provider: .codex, sessionID: "s", projectName: String(repeating: "p", count: 257), phase: .idle,
            toolCategory: nil, elapsedSeconds: nil, updatedAt: now, needsAttention: false
        )
        XCTAssertThrowsError(try SyncedStateValidator.validate(makeEnvelope(snapshot: makeSnapshot(sessions: [long])), now: now))
    }

    func testPercentagesMustBeFiniteAndInRange() {
        for bad in [Double.nan, .infinity, -1, 101] {
            let allowance = WidgetAllowanceSummary(
                provider: .claude, currentWindowLabel: "5h", currentPercentLeft: bad,
                currentResetAt: nil, weeklyPercentLeft: nil, weeklyResetAt: nil, fetchedAt: now
            )
            XCTAssertThrowsError(
                try SyncedStateValidator.validate(makeEnvelope(snapshot: makeSnapshot(allowances: [allowance])), now: now),
                "\(bad) should be rejected"
            ) { error in
                XCTAssertEqual(error as? SyncedStateValidationError, .invalidAllowance)
            }
        }
    }

    func testUnknownPercentageIsValid() throws {
        let allowance = WidgetAllowanceSummary(
            provider: .claude, currentWindowLabel: "5h", currentPercentLeft: nil,
            currentResetAt: nil, weeklyPercentLeft: nil, weeklyResetAt: nil, fetchedAt: now
        )
        XCTAssertNoThrow(try SyncedStateValidator.validate(makeEnvelope(snapshot: makeSnapshot(allowances: [allowance])), now: now))
    }

    func testPoolBoundsAreChecked() {
        let pools = (0..<9).map { WidgetAllowancePool(id: "p\($0)", label: "Pool", percentLeft: 50, resetAt: nil) }
        let allowance = WidgetAllowanceSummary(
            provider: .cursor, currentWindowLabel: "Billing cycle", currentPercentLeft: nil,
            currentResetAt: nil, weeklyPercentLeft: nil, weeklyResetAt: nil, pools: pools, fetchedAt: now
        )
        XCTAssertThrowsError(try SyncedStateValidator.validate(makeEnvelope(snapshot: makeSnapshot(allowances: [allowance])), now: now)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .invalidAllowance)
        }
    }

    func testObservationFarInTheFutureIsRejectedButSkewIsTolerated() {
        let skewed = makeEnvelope(observedAt: now.addingTimeInterval(10 * 60))
        XCTAssertNoThrow(try SyncedStateValidator.validate(skewed, now: now))
        let future = makeEnvelope(observedAt: now.addingTimeInterval(SyncedStateValidator.maximumFutureSkew + 1))
        XCTAssertThrowsError(try SyncedStateValidator.validate(future, now: now)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .observedInTheFuture)
        }
    }

    // MARK: Selection

    func testMostRecentlyObservedMacWins() {
        let older = makeEnvelope(macID: UUID().uuidString, macName: "Old", observedAt: now.addingTimeInterval(-600))
        let newer = makeEnvelope(macID: UUID().uuidString, macName: "New", observedAt: now)
        XCTAssertEqual(SyncedStateSelection.mostRecentlyObserved([older, newer])?.sourceMacName, "New")
        XCTAssertNil(SyncedStateSelection.mostRecentlyObserved([]))
    }

    // MARK: CloudKit record mapping (offline, no container)

    func testRecordRoundTrip() throws {
        let envelope = makeEnvelope()
        let record = CKRecord(recordType: CloudKitSyncRecord.recordType, recordID: CKRecord.ID(recordName: "latest"))
        try CloudKitSyncRecord.apply(envelope, to: record)
        XCTAssertEqual(record[CloudKitSyncRecord.sourceMacIDKey] as? String, macID)
        XCTAssertEqual(record[CloudKitSyncRecord.observedAtKey] as? Date, now)
        XCTAssertEqual(try CloudKitSyncRecord.envelope(from: record), envelope)
    }

    func testRecordWithoutPayloadIsMalformed() {
        let record = CKRecord(recordType: CloudKitSyncRecord.recordType, recordID: CKRecord.ID(recordName: "latest"))
        XCTAssertThrowsError(try CloudKitSyncRecord.envelope(from: record)) { error in
            XCTAssertEqual(error as? SyncedStateValidationError, .malformed)
        }
    }

    func testRecordNamesAreStablePerMac() {
        XCTAssertEqual(CloudKitSyncRecord.perMacRecordName(sourceMacID: macID), "mac-\(macID)")
        XCTAssertEqual(CloudKitSyncRecord.latestRecordName, "latest")
    }

    // MARK: App Group cache

    func testCacheRoundTripsAndReportsHonestStates() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(AppGroupSyncedStateStore(containerDirectory: { nil }).load(), .notConfigured)
        let store = AppGroupSyncedStateStore(containerDirectory: { directory })
        XCTAssertEqual(store.load(), .noSnapshotYet)

        try store.save(makeEnvelope())
        XCTAssertEqual(store.load(), .loaded(makeEnvelope()))

        try Data("{".utf8).write(to: directory.appendingPathComponent(AppGroupSyncedStateStore.filename))
        XCTAssertEqual(store.load(), .corrupted)
    }

    // MARK: Cache-first source

    func testSourcePrefersWhicheverTheMacObservedLater() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AppGroupSyncedStateStore(containerDirectory: { directory })
        let cached = makeEnvelope(observedAt: now)
        try cache.save(cached)

        // An older record from the network changes nothing.
        let olderFetcher = StubFetcher(result: .success(makeEnvelope(macName: "Older", observedAt: now.addingTimeInterval(-60))))
        let source = CachedSyncedStateSource(cache: cache, fetcher: olderFetcher)
        let result1 = await source.loadSyncedState()
        XCTAssertEqual(result1, .loaded(cached))
        XCTAssertEqual(cache.load(), .loaded(cached))

        // A newer one replaces the cache.
        let newer = makeEnvelope(macName: "Newer", observedAt: now.addingTimeInterval(60))
        let newerSource = CachedSyncedStateSource(cache: cache, fetcher: StubFetcher(result: .success(newer)))
        let result2 = await newerSource.loadSyncedState()
        XCTAssertEqual(result2, .loaded(newer))
        XCTAssertEqual(cache.load(), .loaded(newer))
    }

    func testSourceFallsBackToCacheWhenTheFetchFailsOrHangs() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AppGroupSyncedStateStore(containerDirectory: { directory })
        try cache.save(makeEnvelope())

        let failing = CachedSyncedStateSource(cache: cache, fetcher: StubFetcher(result: .failure(StubError())))
        let result3 = await failing.loadSyncedState()
        XCTAssertEqual(result3, .loaded(makeEnvelope()))

        let hanging = CachedSyncedStateSource(cache: cache, fetcher: HangingFetcher(), timeout: .milliseconds(50))
        let result4 = await hanging.loadSyncedState()
        XCTAssertEqual(result4, .loaded(makeEnvelope()))

        let offline = CachedSyncedStateSource(cache: cache, fetcher: nil)
        let result5 = await offline.loadSyncedState()
        XCTAssertEqual(result5, .loaded(makeEnvelope()))
    }

    func testSourceWithNothingAnywhereIsNoSnapshotYet() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AppGroupSyncedStateStore(containerDirectory: { directory })
        let source = CachedSyncedStateSource(cache: cache, fetcher: StubFetcher(result: .success(nil)))
        let result6 = await source.loadSyncedState()
        XCTAssertEqual(result6, .noSnapshotYet)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncedStateEnvelopeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private struct StubError: Error {}

private struct StubFetcher: SyncedStateFetching {
    let result: Result<SyncedStateEnvelope?, StubError>
    func fetchLatest() async throws -> SyncedStateEnvelope? { try result.get() }
}

private struct HangingFetcher: SyncedStateFetching {
    func fetchLatest() async throws -> SyncedStateEnvelope? {
        try await Task.sleep(for: .seconds(30))
        return nil
    }
}
