import Darwin
import Foundation

public enum SessionStateStoreError: Error, Equatable {
    case unsafeDirectory
    case unsafeFile
}

public protocol SessionStateStoring {
    func write(_ event: NormalizedEvent) throws
    func loadAll() throws -> [NormalizedEvent]
    func load(_ key: SessionKey) throws -> NormalizedEvent?
    func remove(_ key: SessionKey) throws
}

public final class FileSessionStateStore: SessionStateStoring {
    public let directory: URL
    private let fileManager: FileManager
    private let currentUserID: () -> uid_t

    public init(
        directory: URL,
        fileManager: FileManager = .default,
        currentUserID: @escaping () -> uid_t = { getuid() }
    ) {
        self.directory = directory
        self.fileManager = fileManager
        self.currentUserID = currentUserID
    }

    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Klarity/Sessions", isDirectory: true)
    }

    public func write(_ event: NormalizedEvent) throws {
        try event.validate()
        try prepareDirectory()

        let destination = directory.appendingPathComponent(SessionKey(event).filename)
        try rejectSymlink(destination)

        let temporary = directory.appendingPathComponent(".\(UUID().uuidString).tmp")
        let data = try JSONEncoder.klarity.encode(event)
        try data.write(to: temporary, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }

        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    public func loadAll() throws -> [NormalizedEvent] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        try validateOwnedDirectory()

        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .compactMap { url in
            do {
                try validateOwnedFile(at: url)
                let event = try JSONDecoder.klarity.decode(
                    NormalizedEvent.self,
                    from: Data(contentsOf: url)
                )
                try event.validate()
                return event
            } catch {
                return nil
            }
        }
    }

    public func load(_ key: SessionKey) throws -> NormalizedEvent? {
        guard fileManager.fileExists(atPath: directory.path) else {
            return nil
        }

        try validateOwnedDirectory()

        let url = directory.appendingPathComponent(key.filename)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        try validateOwnedFile(at: url)

        let event = try JSONDecoder.klarity.decode(
            NormalizedEvent.self,
            from: Data(contentsOf: url)
        )
        try event.validate()
        return event
    }

    public func remove(_ key: SessionKey) throws {
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        try validateOwnedDirectory()

        let url = directory.appendingPathComponent(key.filename)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try validateOwnedFile(at: url)
        try fileManager.removeItem(at: url)
    }

    private func prepareDirectory() throws {
        if fileManager.fileExists(atPath: directory.path) {
            try validateOwnedDirectory()
        } else {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private func validateOwnedDirectory() throws {
        try rejectSymlink(directory)
        try validateOwnership(at: directory, error: .unsafeDirectory)
    }

    private func validateOwnedFile(at url: URL) throws {
        try rejectSymlink(url)
        try validateOwnership(at: url, error: .unsafeFile)
    }

    private func validateOwnership(at url: URL, error: SessionStateStoreError) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let owner = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value
        if let owner, owner != currentUserID() {
            throw error
        }
    }

    private func rejectSymlink(_ url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            if errno == ENOENT {
                return
            }
            throw SessionStateStoreError.unsafeFile
        }

        if (info.st_mode & S_IFMT) == S_IFLNK {
            throw SessionStateStoreError.unsafeDirectory
        }
    }
}
