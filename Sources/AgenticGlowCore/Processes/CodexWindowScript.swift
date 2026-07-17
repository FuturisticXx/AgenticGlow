import Foundation

/// Builds the AppleScript source used to raise a specific Codex (ChatGPT.app)
/// window from within its own process, sidestepping the cross-app activation
/// restriction that makes `NSRunningApplication.activate()` unreliable for a
/// background/.accessory app on macOS 14+.
enum CodexWindowScript {
    static let codexBundleIdentifier = "com.openai.codex"

    static func source(projectName: String) -> String {
        let escaped = escape(projectName)
        return """
        tell application id "\(codexBundleIdentifier)"
            activate
            try
                set matchedWindows to (every window whose name contains "\(escaped)")
                if (count of matchedWindows) > 0 then
                    set index of item 1 of matchedWindows to 1
                end if
            end try
        end tell
        """
    }

    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
