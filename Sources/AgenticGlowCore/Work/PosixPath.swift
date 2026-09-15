/// Absolute-path arithmetic done on the string itself.
///
/// `URL(fileURLWithPath:)` truncates at PATH_MAX on some Foundation
/// versions, so the same working directory produced a different last
/// component on CI than it did locally. Nothing here touches the file
/// system or resolves symlinks, which matches what the callers want: the
/// path a session reported, tidied but not investigated.
public enum PosixPath {
    /// Non-empty components, with "." and ".." resolved. Ascending past
    /// root clamps to root rather than escaping it.
    public static func components(_ path: String) -> [String] {
        var stack: [String] = []
        for component in path.split(separator: "/") {
            switch component {
            case ".":
                continue
            case "..":
                if !stack.isEmpty { stack.removeLast() }
            default:
                stack.append(String(component))
            }
        }
        return stack
    }

    /// Absolute path with "." and ".." resolved and repeated or trailing
    /// separators collapsed. Root stays "/".
    public static func standardized(_ path: String) -> String {
        let parts = components(path)
        return parts.isEmpty ? "/" : "/" + parts.joined(separator: "/")
    }

    /// Last path component, or nil for a path that names only root.
    public static func lastComponent(_ path: String) -> String? {
        components(path).last
    }
}
