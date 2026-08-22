import Foundation

/// Exact normalized working directory. Phase 1 identity is the path the
/// session reported, not a git root and not a resolved symlink.
public struct WorkIdentity: Hashable, Sendable, Equatable {
    public let rawPath: String
    /// Grouping key. A normalized absolute path, or `session:{id}` when
    /// the reported path is missing or invalid.
    public let value: String

    public var isPath: Bool {
        value.hasPrefix("/")
    }

    public static func normalize(path: String) -> WorkIdentity? {
        guard !path.isEmpty, path.hasPrefix("/"), !path.contains("\u{0}") else {
            return nil
        }
        var normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        if normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return WorkIdentity(rawPath: path, value: normalized)
    }

    public static func singleton(for session: SessionSnapshot) -> WorkIdentity {
        WorkIdentity(rawPath: session.workingDirectory, value: "session:\(session.id)")
    }

    public static func identity(for session: SessionSnapshot) -> WorkIdentity {
        normalize(path: session.workingDirectory) ?? singleton(for: session)
    }
}
