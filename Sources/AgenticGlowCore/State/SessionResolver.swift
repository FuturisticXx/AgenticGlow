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
            if let pid = event.sourceProcessID {
                if !isProcessAlive(pid, event.sourceProcessStartedAt) {
                    let key = SessionKey(event)
                    let record: DisconnectionRecord
                    if let storedRecord = memory.disconnectedRecords[key],
                       storedRecord.eventUpdatedAt == event.updatedAt {
                        record = storedRecord
                    } else {
                        record = DisconnectionRecord(
                            eventUpdatedAt: event.updatedAt,
                            detectedAt: now
                        )
                    }
                    memory.disconnectedRecords[key] = record
                    guard now.timeIntervalSince(record.detectedAt) <= disconnectedDisplayDuration else {
                        return nil
                    }
                    phase = .disconnected
                } else if event.phase == .completed && age > completionDisplayDuration {
                    memory.disconnectedRecords.removeValue(forKey: SessionKey(event))
                    phase = .idle
                } else {
                    memory.disconnectedRecords.removeValue(forKey: SessionKey(event))
                    phase = event.phase
                }
            } else {
                memory.disconnectedRecords.removeValue(forKey: SessionKey(event))
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
            permissionCount: snapshots.filter { $0.phase == .permission }.count,
            activeProviders: Set(
                snapshots
                    .filter { [.thinking, .usingTool].contains($0.phase) }
                    .map(\.provider)
            )
        )
    }

    private static func sort(_ lhs: SessionSnapshot, _ rhs: SessionSnapshot) -> Bool {
        let left = priority(lhs.phase)
        let right = priority(rhs.phase)
        if left != right { return left < right }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.provider != rhs.provider { return lhs.provider.rawValue < rhs.provider.rawValue }
        return lhs.sessionID < rhs.sessionID
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
