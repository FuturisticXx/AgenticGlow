import Foundation

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
            return 0
        } catch {
            return 1
        }
    }
}
