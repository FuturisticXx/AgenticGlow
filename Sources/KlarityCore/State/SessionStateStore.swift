import Darwin
import Foundation

public enum SessionStateStoreError: Error {
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

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
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

        try rejectSymlink(directory)

        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .compactMap { url in
            do {
                try rejectSymlink(url)
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

        try rejectSymlink(directory)

        let url = directory.appendingPathComponent(key.filename)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        try rejectSymlink(url)

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

        try rejectSymlink(directory)

        let url = directory.appendingPathComponent(key.filename)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try rejectSymlink(url)
        try fileManager.removeItem(at: url)
    }

    private func prepareDirectory() throws {
        if fileManager.fileExists(atPath: directory.path) {
            try rejectSymlink(directory)
            let attributes = try fileManager.attributesOfItem(atPath: directory.path)
            let owner = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value
            if let owner, owner != getuid() {
                throw SessionStateStoreError.unsafeDirectory
            }
        } else {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
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
