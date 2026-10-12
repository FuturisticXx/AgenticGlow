import Foundation
import Observation
import Security
import AgenticGlowCore

/// Receives every snapshot the app builds and decides whether it is worth
/// publishing for the iPhone widget.
protocol WidgetSnapshotSyncing: AnyObject {
    @MainActor func snapshotDidRefresh(_ snapshot: WidgetSnapshot, now: Date)
}

/// This Mac's identity in synchronized state: a random UUID minted once
/// per install and the user-visible computer name. Never a serial number
/// or any other hardware identifier.
struct MacSyncIdentity {
    static let defaultsKey = "syncSourceMacID"

    let sourceMacID: String
    let sourceMacName: String

    static func stored(in defaults: UserDefaults = .standard) -> MacSyncIdentity {
        let id: String
        if let existing = defaults.string(forKey: defaultsKey), UUID(uuidString: existing) != nil {
            id = existing
        } else {
            id = UUID().uuidString
            defaults.set(id, forKey: defaultsKey)
        }
        let name = Host.current().localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return MacSyncIdentity(
            sourceMacID: id,
            sourceMacName: name.isEmpty ? "Mac" : String(name.prefix(SyncedStateValidator.maximumMacNameLength))
        )
    }
}

/// Whether this process may talk to the iCloud container at all. A local
/// build signed without the iCloud capability (or not signed, as in the
/// test runners) has no entitlement, and CloudKit answers a missing
/// entitlement with an Objective-C exception rather than an error, so
/// the check has to happen before a container is ever created.
enum CloudKitEntitlement {
    static func isPresent(for containerIdentifier: String = CloudKitSyncTransport.containerIdentifier) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.icloud-container-identifiers" as CFString,
            nil
        )
        return (value as? [String])?.contains(containerIdentifier) ?? false
    }
}

/// Publishes the widget snapshot to the user's private iCloud database for
/// the iPhone widget: on every meaningful change, and on a heartbeat while
/// nothing changes, so the phone can tell a quiet Mac from a missing one.
///
/// Off unless the preference is on. Publishes nothing the desktop widget
/// does not already receive: the same `WidgetSnapshot`, wrapped with the
/// Mac's random install identifier, its computer name, and the time.
@MainActor
@Observable
final class StateSyncService: WidgetSnapshotSyncing {
    /// After a failed publish, how long to wait before trying again, so
    /// an iCloud outage costs one request a minute rather than one every
    /// refresh tick.
    static let retryInterval: TimeInterval = 60

    private let transport: (any SyncedStatePublishing)?
    private let identity: MacSyncIdentity
    private let isEnabled: () -> Bool
    private var lastPublished: WidgetSnapshot?
    private var lastPublishedAt: Date?
    private var lastFailureAt: Date?
    private var publishTask: Task<Void, Never>?
    /// The most recent snapshot the model offered, whether or not it was
    /// published. What "Publish & Verify" sends.
    private var latestOffered: WidgetSnapshot?

    /// One line for Settings, never a credential or an account identity.
    private(set) var status = "Off"

    /// `transport` is nil when the build carries no iCloud entitlement.
    init(
        transport: (any SyncedStatePublishing)?,
        identity: MacSyncIdentity,
        isEnabled: @escaping () -> Bool
    ) {
        self.transport = transport
        self.identity = identity
        self.isEnabled = isEnabled
        if transport == nil {
            status = "This build is not signed for iCloud"
        }
    }

    var isAvailable: Bool { transport != nil }

    func snapshotDidRefresh(_ snapshot: WidgetSnapshot, now: Date) {
        latestOffered = snapshot
        guard let transport, isEnabled() else {
            if transport != nil { status = "Off" }
            lastPublished = nil
            lastPublishedAt = nil
            return
        }
        guard publishTask == nil else { return }
        if let lastFailureAt, now.timeIntervalSince(lastFailureAt) < Self.retryInterval {
            return
        }
        let changed = lastPublished.map { WidgetSnapshotBuilder.isMeaningfullyDifferent(snapshot, from: $0) } ?? true
        guard SyncPublishingPolicy.shouldPublish(changed: changed, lastPublishedAt: lastPublishedAt, now: now) else {
            return
        }
        let envelope = SyncedStateEnvelope(
            sourceMacID: identity.sourceMacID,
            sourceMacName: identity.sourceMacName,
            observedAt: now,
            snapshot: snapshot
        )
        publishTask = Task { [weak self] in
            do {
                try await transport.publish(envelope)
                self?.didPublish(snapshot, at: now)
            } catch {
                self?.didFail(error, at: now)
            }
            self?.publishTask = nil
        }
    }

    private func didPublish(_ snapshot: WidgetSnapshot, at date: Date) {
        lastPublished = snapshot
        lastPublishedAt = date
        lastFailureAt = nil
        status = "Published \(date.formatted(date: .omitted, time: .shortened))"
    }

    #if DEBUG
    /// Publishes the latest offered snapshot now, regardless of the
    /// heartbeat, and proves the CloudKit round trip. Debug builds only;
    /// the report names fields and hashes, never payload contents.
    func publishAndVerify() async -> SyncVerificationReport {
        var report = SyncVerificationReport()
        guard let transport = transport as? any SyncVerificationTransport else {
            report.add("CloudKit account", "this build carries no iCloud entitlement", passed: false)
            return report
        }
        guard let snapshot = latestOffered else {
            report.add("Snapshot", "none built yet", passed: false)
            return report
        }
        let envelope = SyncedStateEnvelope(
            sourceMacID: identity.sourceMacID,
            sourceMacName: identity.sourceMacName,
            observedAt: Date(),
            snapshot: snapshot
        )
        return await SyncRoundTripVerifier.verify(envelope, transport: transport)
    }
    #endif

    private func didFail(_ error: Error, at date: Date) {
        lastFailureAt = date
        // The error's description names iCloud account and network states,
        // never the payload; it is shown, not logged.
        status = "Not published: \(error.localizedDescription)"
    }
}
