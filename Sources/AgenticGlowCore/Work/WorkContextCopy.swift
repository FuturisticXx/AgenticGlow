import Foundation

/// Pasteboard text for a session. Path, harness, model, phase, and last
/// updated only. Never includes prompts or transcripts.
public enum WorkContextCopy {
    public static func text(for session: SessionSnapshot, now: Date = Date()) -> String {
        var lines = [
            session.projectName,
            session.workingDirectory,
            session.provider.displayName
        ]
        if let model = session.model, !model.isEmpty {
            lines.append(model)
        }
        lines.append(WorkStatusLine.phaseLabel(session.phase))
        lines.append(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
        return lines.joined(separator: "\n")
    }

    public static func canReveal(_ session: SessionSnapshot) -> Bool {
        WorkIdentity.normalize(path: session.workingDirectory) != nil
    }
}
