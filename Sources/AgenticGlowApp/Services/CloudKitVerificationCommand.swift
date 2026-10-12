#if DEBUG
import AppKit
import Foundation
import AgenticGlowCore

/// `AgenticGlow --verify-cloudkit-sync [--observed-at-offset SECONDS]`
///
/// Debug builds only. Takes the snapshot the installed app last wrote to
/// the App Group (the real, current state, produced without this process
/// touching a provider or the Keychain), publishes it through the real
/// CloudKit transport, reads it back, and prints the round-trip report to
/// stdout. The optional offset shifts only this envelope's `observedAt`,
/// so the iPhone's stale and offline presentation can be exercised
/// without waiting; the production freshness classifier is untouched.
/// Exits with 0 on PASS, 1 on FAIL, 2 when it cannot run.
enum CloudKitVerificationCommand {
    static let argument = "--verify-cloudkit-sync"
    static let offsetArgument = "--observed-at-offset"

    static var isRequested: Bool {
        CommandLine.arguments.contains(argument)
    }

    static func run() async -> Int32 {
        let arguments = CommandLine.arguments
        var offset: TimeInterval = 0
        if let index = arguments.firstIndex(of: offsetArgument), index + 1 < arguments.count {
            offset = TimeInterval(arguments[index + 1]) ?? 0
        }
        guard CloudKitEntitlement.isPresent() else {
            print("Cannot verify: this build carries no iCloud entitlement.")
            return 2
        }
        let snapshot: WidgetSnapshot
        switch AppGroupSnapshotSource().loadSnapshot() {
        case let .loaded(loaded):
            snapshot = loaded
        case let other:
            print("Cannot verify: no installed-app snapshot in the App Group (\(other)).")
            return 2
        }
        let identity = MacSyncIdentity.stored()
        let observedAt = Date().addingTimeInterval(offset)
        let envelope = SyncedStateEnvelope(
            sourceMacID: identity.sourceMacID,
            sourceMacName: identity.sourceMacName,
            observedAt: observedAt,
            snapshot: snapshot
        )
        print("Source: installed app snapshot generated \(snapshot.generatedAt.formatted(date: .abbreviated, time: .standard))")
        // The same figures the widgets draw, so a phone can be compared to
        // this run line by line. Percentages and phases only; no names.
        let sessions = snapshot.sessions.map { "\($0.provider.rawValue):\($0.phase.rawValue)" }.joined(separator: " ")
        print("Sessions: \(snapshot.sessions.count) [\(sessions)] attention \(snapshot.attentionCount) active \(snapshot.activeCount)")
        for allowance in snapshot.allowances {
            let windows = allowance.windows.map { window in
                let percent = window.percentLeft.map { "\(Int($0.rounded()))%" } ?? "n/a"
                let reset = window.resetAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "no reset"
                return "\(window.label) \(percent) resets \(reset)"
            }
            print("Allowance \(allowance.provider.rawValue): \(windows.joined(separator: " | "))")
        }
        print("observedAt: \(observedAt.formatted(date: .abbreviated, time: .standard)) (offset \(Int(offset))s)")
        let report = await SyncRoundTripVerifier.verify(envelope, transport: CloudKitSyncTransport())
        print(report.text)
        return report.passed ? 0 : 1
    }
}
#endif
