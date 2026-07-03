import Foundation

public struct AgenticGlowEventCommand {
    private let store: SessionStateStoring
    private let processIdentity: (AgentProvider, [String: String]) -> ProcessIdentity?
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
        else {
            return 64
        }

        do {
            let normalizedCandidate = try HookNormalizer.normalize(
                provider: provider,
                event: event,
                payload: payload,
                environment: environment,
                processIdentity: processIdentity(provider, environment),
                previous: nil,
                now: now
            )

            guard let normalizedCandidate else {
                return 0
            }

            let previous = try store.load(SessionKey(normalizedCandidate))
            guard let normalized = try HookNormalizer.normalize(
                provider: provider,
                event: event,
                payload: payload,
                environment: environment,
                processIdentity: processIdentity(provider, environment),
                previous: previous,
                now: now
            ) else {
                return 0
            }

            if event == .sessionEnd {
                try store.remove(SessionKey(normalized))
            } else {
                try store.write(normalized)
            }
            logger?.record(
                provider: provider,
                event: event,
                sessionID: normalized.sessionID,
                result: "written",
                rawPayload: nil
            )
            return 0
        } catch {
            logger?.record(
                provider: provider,
                event: event,
                sessionID: payload["session_id"] as? String ?? "unknown",
                result: "failed:\(String(describing: type(of: error)))",
                rawPayload: nil
            )
            return 1
        }
    }
}
