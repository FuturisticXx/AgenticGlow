import Foundation

public enum ExecutableLocator {
    public static func locate(_ name: String) -> URL? {
        guard ["codex", "claude"].contains(name) else { return nil }
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
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let path = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0,
              FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    static func candidatePaths(for name: String, homeDirectory: String) -> [String] {
        let appBinary = name == "codex"
            ? ["/Applications/Codex.app/Contents/Resources/codex"]
            : []
        return appBinary + [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "\(homeDirectory)/.local/bin/\(name)",
            "\(homeDirectory)/bin/\(name)"
        ]
    }
}
