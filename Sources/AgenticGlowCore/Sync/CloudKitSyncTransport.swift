import CloudKit
import Foundation

/// How an envelope is laid out in a CloudKit record. Pure, so the mapping
/// is testable without a container: `CKRecord` values can be built and
/// read offline.
public enum CloudKitSyncRecord {
    public static let recordType = "AgenticGlowState"
    /// One record per Mac, keyed by its random install identifier.
    public static func perMacRecordName(sourceMacID: String) -> String {
        "mac-\(sourceMacID)"
    }
    /// One well-known record every Mac also overwrites. The iPhone reads
    /// this by name, which needs no query and no index, and gets exactly
    /// the most recently observed state. The per-Mac records are what a
    /// future picker would enumerate.
    public static let latestRecordName = "latest"

    public static let payloadKey = "payload"
    public static let schemaVersionKey = "schemaVersion"
    public static let sourceMacIDKey = "sourceMacID"
    public static let observedAtKey = "observedAt"

    /// Writes the envelope into `record`. The whole envelope travels as
    /// one JSON payload so there is a single decode-and-validate path;
    /// the three loose fields exist only so the CloudKit dashboard can
    /// tell records apart.
    public static func apply(_ envelope: SyncedStateEnvelope, to record: CKRecord) throws {
        record[payloadKey] = try SyncedStateCodec.encode(envelope) as NSData
        record[schemaVersionKey] = envelope.schemaVersion as NSNumber
        record[sourceMacIDKey] = envelope.sourceMacID as NSString
        record[observedAtKey] = envelope.observedAt as NSDate
    }

    /// Decodes and validates the payload, ignoring the loose fields: the
    /// payload is the one source of truth.
    public static func envelope(from record: CKRecord) throws -> SyncedStateEnvelope {
        guard let data = record[payloadKey] as? Data else {
            throw SyncedStateValidationError.malformed
        }
        return try SyncedStateCodec.decode(data)
    }
}

/// Publishes to, and fetches from, the user's private CloudKit database.
///
/// Private database only: the data never leaves the user's own iCloud
/// account, and Apple encrypts it in transit and at rest. No AgenticGlow
/// server exists anywhere in this path. Both platforms use this type; the
/// Mac only publishes and the iPhone only fetches.
public struct CloudKitSyncTransport: SyncedStatePublishing, SyncedStateFetching {
    public static let containerIdentifier = "iCloud.com.twodamax.agenticglow"

    let database: CKDatabase
    let containerIdentifier: String

    /// Only construct this once the iCloud entitlement is known to be
    /// present: CloudKit raises an Objective-C exception, not a Swift
    /// error, for a container the process is not entitled to.
    public init(containerIdentifier: String = CloudKitSyncTransport.containerIdentifier) {
        self.containerIdentifier = containerIdentifier
        database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
    }

    public func publish(_ envelope: SyncedStateEnvelope) async throws {
        let perMac = CKRecord(
            recordType: CloudKitSyncRecord.recordType,
            recordID: CKRecord.ID(recordName: CloudKitSyncRecord.perMacRecordName(sourceMacID: envelope.sourceMacID))
        )
        let latest = CKRecord(
            recordType: CloudKitSyncRecord.recordType,
            recordID: CKRecord.ID(recordName: CloudKitSyncRecord.latestRecordName)
        )
        try CloudKitSyncRecord.apply(envelope, to: perMac)
        try CloudKitSyncRecord.apply(envelope, to: latest)
        // `.allKeys` overwrites whatever is there regardless of change
        // tag: the newest observation always wins, and there is nothing
        // to merge.
        let (saveResults, _) = try await database.modifyRecords(
            saving: [perMac, latest],
            deleting: [],
            savePolicy: .allKeys,
            atomically: true
        )
        for (_, result) in saveResults {
            _ = try result.get()
        }
    }

    public func fetchLatest() async throws -> SyncedStateEnvelope? {
        let recordID = CKRecord.ID(recordName: CloudKitSyncRecord.latestRecordName)
        do {
            let record = try await database.record(for: recordID)
            return try CloudKitSyncRecord.envelope(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    /// Whether this device can reach the container at all. Used by the
    /// iPhone app's status screen; never by the widget, which renders
    /// from its cache regardless.
    public static func accountStatus(
        containerIdentifier: String = CloudKitSyncTransport.containerIdentifier
    ) async throws -> CKAccountStatus {
        try await CKContainer(identifier: containerIdentifier).accountStatus()
    }
}

/// What the iPhone widget and app render from: the App Group cache first,
/// then CloudKit when it answers in time, keeping whichever the Mac
/// observed more recently and writing that back to the cache.
///
/// The cache is the primary source and the fetch is opportunistic. iOS
/// decides when a widget may run and for how long, so a render must never
/// depend on the network; and a fetch that fails or returns something
/// older than the cache changes nothing. Freshness is still judged from
/// `observedAt`, so retrieving an old record cannot make it look current.
public struct CachedSyncedStateSource: SyncedStateLoading {
    private let cache: any SyncedStateCaching
    private let fetcher: (any SyncedStateFetching)?
    private let timeout: Duration

    public init(
        cache: any SyncedStateCaching,
        fetcher: (any SyncedStateFetching)?,
        timeout: Duration = .seconds(8)
    ) {
        self.cache = cache
        self.fetcher = fetcher
        self.timeout = timeout
    }

    public func loadSyncedState() async -> SyncedStateLoadResult {
        let cached = cache.load()
        if case .notConfigured = cached { return cached }
        guard let fetcher, let fetched = await fetchWithTimeout(fetcher) else { return cached }
        if case let .loaded(existing) = cached, existing.observedAt >= fetched.observedAt {
            return cached
        }
        try? cache.save(fetched)
        return .loaded(fetched)
    }

    private func fetchWithTimeout(_ fetcher: any SyncedStateFetching) async -> SyncedStateEnvelope? {
        await withTaskGroup(of: SyncedStateEnvelope?.self) { group in
            group.addTask { try? await fetcher.fetchLatest() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
