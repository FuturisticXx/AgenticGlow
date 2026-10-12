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

    /// The environment to launch a located executable with. A GUI app
    /// inherits launchd's minimal PATH, so an npm-installed launcher such
    /// as Homebrew's `codex` (`#!/usr/bin/env node`) cannot find the
    /// `node` installed beside it and exits 127 before answering. The
    /// launcher's own directory goes first; nothing else is added.
    public static func launchEnvironment(
        for executableURL: URL,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = base
        let directory = (executableURL.path as NSString).deletingLastPathComponent
        let inherited = base["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = directory.isEmpty ? inherited : "\(directory):\(inherited)"
        return environment
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
            // The app bundles moved the CLI into `codex-cli/bin` (seen in
            // ChatGPT 26.930, 2026-10-04). The old location is kept for
            // installs that have not updated yet.
            appBinary = [
                "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
                "/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex",
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
