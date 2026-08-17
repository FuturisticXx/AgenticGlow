import Foundation

public enum ExecutableLocator {
    public static func locate(_ name: String) -> URL? {
        guard ["codex", "claude", "cursor"].contains(name) else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if let direct = candidatePaths(for: name, homeDirectory: home)
            .map(URL.init(fileURLWithPath:))
            .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return direct
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lic", "command -v \(name)"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else {
            return locateFallbackApplication(named: name)
        }
        process.waitUntilExit()
        let path = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0,
              FileManager.default.isExecutableFile(atPath: path) else {
            return locateFallbackApplication(named: name)
        }
        return URL(fileURLWithPath: path)
    }

    /// Cursor is a GUI app first. The CLI may be absent from PATH even when
    /// `/Applications/Cursor.app` is installed, so Setup still treats that as
    /// detected rather than "Not Installed".
    public static func locateCursorApplication() -> URL? {
        locateFallbackApplication(named: "cursor")
    }

    private static func locateFallbackApplication(named name: String) -> URL? {
        guard name == "cursor" else { return nil }
        let url = URL(fileURLWithPath: "/Applications/Cursor.app")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return url
    }

    static func candidatePaths(for name: String, homeDirectory: String) -> [String] {
        let appBinary: [String]
        switch name {
        case "codex":
            appBinary = [
                "/Applications/ChatGPT.app/Contents/Resources/codex",
                "/Applications/Codex.app/Contents/Resources/codex"
            ]
        case "cursor":
            appBinary = [
                "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
            ]
        default:
            appBinary = []
        }
        return appBinary + [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "\(homeDirectory)/.local/bin/\(name)",
            "\(homeDirectory)/bin/\(name)"
        ]
    }
}
