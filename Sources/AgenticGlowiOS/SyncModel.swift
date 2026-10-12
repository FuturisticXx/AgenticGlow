import CloudKit
import Foundation
import Observation
import WidgetKit
import AgenticGlowCore

/// Keeps the App Group cache current and reports what the phone knows.
///
/// Every path ends in the same place: whatever is newest by the Mac's own
/// `observedAt` is written to the cache and the widget timelines are
/// reloaded. Nothing here ever advances `observedAt`; a fetch that finds
/// the same old record leaves the widget reporting the same old age.
@MainActor
@Observable
final class SyncModel {
    private(set) var state: SyncedStateLoadResult
    private(set) var accountStatus: CKAccountStatus?
    private(set) var lastRefreshAt: Date?
    private(set) var lastError: String?
    private(set) var isRefreshing = false

    private let cache: any SyncedStateCaching
    private let source: any SyncedStateLoading
    private let containerIdentifier: String
    #if DEBUG
    private(set) var verificationReport: SyncVerificationReport?
    private(set) var lastFetchStatus = "not attempted"
    private(set) var lastFetchAt: Date?
    var cacheWrittenAt: Date? {
        (cache as? AppGroupSyncedStateStore)?.lastWriteDate()
    }
    #endif

    init(
        cache: any SyncedStateCaching = AppGroupSyncedStateStore(),
        containerIdentifier: String = CloudKitSyncTransport.containerIdentifier
    ) {
        self.cache = cache
        self.containerIdentifier = containerIdentifier
        source = CachedSyncedStateSource(
            cache: cache,
            fetcher: CloudKitSyncTransport(containerIdentifier: containerIdentifier)
        )
        state = cache.load()
    }

    /// Fetches, caches, and reloads the widget timelines. Returns whether
    /// something newer arrived. The reload is unconditional: it is what
    /// lets the widget pick up whatever the cache now holds, and a reload
    /// requested while the app is in the foreground, or on a push, is
    /// exactly the case WidgetKit budgets for.
    @discardableResult
    func refresh() async -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        defer { isRefreshing = false }
        accountStatus = try? await CloudKitSyncTransport.accountStatus(containerIdentifier: containerIdentifier)
        let before = state
        state = await source.loadSyncedState()
        lastRefreshAt = Date()
        lastError = nil
        WidgetCenter.shared.reloadAllTimelines()
        return state != before
    }

    #if DEBUG
    /// The receiving path, one step at a time, with a verdict for each:
    /// CloudKit fetch, envelope validation, decode, App Group cache write,
    /// WidgetKit reload. Debug builds only; the report names fields and
    /// hashes, never payload contents.
    func refreshAndVerify() async {
        var report = SyncVerificationReport()
        let stamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        report.add("Verification started", Date().formatted(stamp))
        accountStatus = try? await CloudKitSyncTransport.accountStatus(containerIdentifier: containerIdentifier)
        report.add("CloudKit account", accountStatus == .available ? "available" : "\(String(describing: accountStatus))", passed: accountStatus == .available)

        let transport = CloudKitSyncTransport(containerIdentifier: containerIdentifier)
        let fetched: SyncedStateEnvelope?
        let started = Date()
        do {
            fetched = try await transport.fetchLatest()
            lastFetchAt = Date()
            lastFetchStatus = fetched == nil ? "no record" : "ok"
            report.add("CloudKit fetch", fetched == nil ? "no record published yet" : "PASS (\(String(format: "%.2f", Date().timeIntervalSince(started)))s)", passed: fetched != nil)
        } catch {
            lastFetchStatus = "error: \(error.localizedDescription)"
            report.add("CloudKit fetch", "FAIL: \(error.localizedDescription)", passed: false)
            fetched = nil
        }
        guard let fetched else {
            verificationReport = report
            return
        }
        do {
            try SyncedStateValidator.validate(fetched)
            report.add("Envelope validation", "PASS")
        } catch {
            report.add("Envelope validation", "FAIL: \(error)", passed: false)
        }
        report.add("Source Mac", fetched.sourceMacName)
        report.add("Mac observedAt", fetched.observedAt.formatted(stamp))
        report.add("Snapshot schema", "\(fetched.snapshot.schemaVersion)")
        report.add("Snapshot hash", SyncedStateFingerprint.hash(of: fetched))
        let freshness = SyncFreshness.evaluate(observedAt: fetched.observedAt, now: Date())
        report.add("Freshness", freshness.summary)
        do {
            try cache.save(fetched)
            report.add("App Group cache write", "PASS")
        } catch {
            report.add("App Group cache write", "FAIL: \(error.localizedDescription)", passed: false)
        }
        let reread = cache.load()
        report.add("App Group cache read-back", reread == .loaded(fetched) ? "PASS" : "FAIL", passed: reread == .loaded(fetched))
        state = reread
        WidgetCenter.shared.reloadAllTimelines()
        report.add("WidgetKit reload", "requested")
        report.add("Result", report.passed ? "PASS" : "FAIL", passed: report.passed)
        verificationReport = report
    }
    #endif

    /// Asks CloudKit to send a silent push whenever the Mac's record
    /// changes. Idempotent: the subscription has a fixed identifier, and
    /// saving it again is a no-op on the server. Best effort: the widget
    /// renders from the cache with or without it, and the timeline's
    /// fallback refresh keeps working when pushes do not arrive.
    func ensureSubscribed() async {
        let subscription = CKQuerySubscription(
            recordType: CloudKitSyncRecord.recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "agenticglow-state-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            _ = try await CKContainer(identifier: containerIdentifier).privateCloudDatabase.save(subscription)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
