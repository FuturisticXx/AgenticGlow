import Foundation

public protocol HelperInstalling {
    var destinationURL: URL { get }
    func install() throws
    func isCurrent() -> Bool
}

public final class HelperInstaller: HelperInstalling {
    public let sourceURL: URL
    public let destinationURL: URL
    private let fileManager: FileManager

    public init(
        sourceURL: URL,
        destinationURL: URL,
        fileManager: FileManager = .default
    ) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.fileManager = fileManager
    }

    public static var defaultDestination: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/Klarity/bin/klarity-event"
            )
    }

    public func install() throws {
        let directory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let temporary = directory.appendingPathComponent(".klarity-event.\(UUID().uuidString)")
        try fileManager.copyItem(at: sourceURL, to: temporary)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destinationURL)
        }
    }

    public func isCurrent() -> Bool {
        guard let source = try? Data(contentsOf: sourceURL),
              let installed = try? Data(contentsOf: destinationURL) else { return false }
        return source == installed
    }
}
