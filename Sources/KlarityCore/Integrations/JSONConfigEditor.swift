import Darwin
import Foundation

public final class JSONConfigEditor {
    private struct Snapshot {
        let data: Data?
        let object: [String: Any]
    }

    private static let maximumMutationAttempts = 3

    private let url: URL
    private let fileManager: FileManager
    private let currentUserID: () -> uid_t

    public init(
        url: URL,
        fileManager: FileManager = .default,
        currentUserID: @escaping () -> uid_t = { getuid() }
    ) {
        self.url = url
        self.fileManager = fileManager
        self.currentUserID = currentUserID
    }

    public func readObjectIfPresent() throws -> [String: Any]? {
        let snapshot = try readSnapshotOnce()
        return snapshot.data == nil ? nil : snapshot.object
    }

    public func mutate(_ change: (inout [String: Any]) throws -> Void) throws {
        for _ in 0..<Self.maximumMutationAttempts {
            let snapshot = try readSnapshotOnce()
            var object = snapshot.object
            try change(&object)
            guard JSONSerialization.isValidJSONObject(object) else {
                throw CocoaError(.propertyListWriteInvalid)
            }
            if NSDictionary(dictionary: snapshot.object).isEqual(to: object) {
                return
            }

            let replacement = try encodedObject(object)
            try prepareParentDirectory()
            guard try currentDataMatches(snapshot.data) else { continue }

            let backup = try snapshot.data.flatMap(writeFirstBackupIfNeeded)
            guard try currentDataMatches(snapshot.data) else {
                removeNewBackup(backup)
                continue
            }

            let temporary: URL
            do {
                temporary = try writeSecureTemporary(replacement)
            } catch {
                removeNewBackup(backup)
                throw error
            }
            guard try currentDataMatches(snapshot.data) else {
                try? fileManager.removeItem(at: temporary)
                removeNewBackup(backup)
                continue
            }

            do {
                try installTemporary(temporary, replacingExisting: snapshot.data != nil)
            } catch {
                try? fileManager.removeItem(at: temporary)
                removeNewBackup(backup)
                if try !currentDataMatches(snapshot.data) { continue }
                throw error
            }
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
            try syncParentDirectory()
            return
        }
        throw CocoaError(.fileWriteFileExists)
    }

    private func readSnapshotOnce() throws -> Snapshot {
        guard let data = try validatedDataIfPresent() else {
            return Snapshot(data: nil, object: [:])
        }
        return Snapshot(data: data, object: try decodeObject(data))
    }

    private func validatedDataIfPresent() throws -> Data? {
        let parent = url.deletingLastPathComponent()
        guard try pathExistsWithoutFollowingSymlinks(at: parent, error: .unsafeDirectory) else {
            return nil
        }
        try validateDirectory(at: parent)

        guard try pathExistsWithoutFollowingSymlinks(at: url, error: .unsafeFile) else {
            return nil
        }
        try validateFile(at: url)
        return try Data(contentsOf: url)
    }

    private func currentDataMatches(_ expected: Data?) throws -> Bool {
        try validatedDataIfPresent() == expected
    }

    private func decodeObject(_ data: Data) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return object
    }

    private func encodedObject(_ object: [String: Any]) throws -> Data {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) + Data("\n".utf8)
        _ = try decodeObject(data)
        return data
    }

    private func prepareParentDirectory() throws {
        let parent = url.deletingLastPathComponent()
        if try pathExistsWithoutFollowingSymlinks(at: parent, error: .unsafeDirectory) {
            try validateDirectory(at: parent)
            return
        }

        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        try validateDirectory(at: parent)
    }

    private func validateDirectory(at candidate: URL) throws {
        let attributes = try safeAttributes(at: candidate, error: .unsafeDirectory)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw SessionStateStoreError.unsafeDirectory
        }
        try validateOwnerAndPermissions(attributes, error: .unsafeDirectory)
    }

    private func validateFile(at candidate: URL) throws {
        let attributes = try safeAttributes(at: candidate, error: .unsafeFile)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw SessionStateStoreError.unsafeFile
        }
        try validateOwnerAndPermissions(attributes, error: .unsafeFile)
    }

    private func safeAttributes(
        at candidate: URL,
        error: SessionStateStoreError
    ) throws -> [FileAttributeKey: Any] {
        guard try pathExistsWithoutFollowingSymlinks(at: candidate, error: error) else {
            throw error
        }
        return try fileManager.attributesOfItem(atPath: candidate.path)
    }

    private func validateOwnerAndPermissions(
        _ attributes: [FileAttributeKey: Any],
        error: SessionStateStoreError
    ) throws {
        guard let owner = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value,
              owner == currentUserID(),
              let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value,
              permissions & 0o022 == 0 else {
            throw error
        }
    }

    private func writeFirstBackupIfNeeded(_ data: Data) throws -> URL? {
        let directory = url.deletingLastPathComponent()
        let prefix = "\(url.lastPathComponent)."
        let existing = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).contains {
            $0.lastPathComponent.hasPrefix(prefix)
                && $0.lastPathComponent.hasSuffix(".bak-klarity")
        }
        guard !existing else { return nil }

        let backup = directory.appendingPathComponent(
            "\(prefix)\(UUID().uuidString).bak-klarity"
        )
        try writeSecure(data, to: backup)
        do {
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        } catch {
            try? fileManager.removeItem(at: backup)
            throw error
        }
        return backup
    }

    private func removeNewBackup(_ backup: URL?) {
        guard let backup else { return }
        try? fileManager.removeItem(at: backup)
    }

    private func writeSecureTemporary(_ data: Data) throws -> URL {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(
            ".\(url.lastPathComponent).\(UUID().uuidString).tmp"
        )
        try writeSecure(data, to: temporary)
        do {
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: temporary.path
            )
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
        return temporary
    }

    private func writeSecure(_ data: Data, to destination: URL) throws {
        let descriptor = open(
            destination.path,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw posixError() }

        var completed = false
        var descriptorIsOpen = true
        defer {
            if descriptorIsOpen { _ = close(descriptor) }
            if !completed { _ = unlink(destination.path) }
        }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    rawBuffer.count - offset
                )
                if written < 0 {
                    if errno == EINTR { continue }
                    throw posixError()
                }
                guard written > 0 else { throw POSIXError(.EIO) }
                offset += written
            }
        }
        guard fsync(descriptor) == 0 else { throw posixError() }
        let closeResult = close(descriptor)
        descriptorIsOpen = false
        guard closeResult == 0 else { throw posixError() }
        completed = true
    }

    private func installTemporary(_ temporary: URL, replacingExisting: Bool) throws {
        if replacingExisting {
            guard rename(temporary.path, url.path) == 0 else { throw posixError() }
            return
        }

        guard link(temporary.path, url.path) == 0 else { throw posixError() }
        guard unlink(temporary.path) == 0 else {
            _ = unlink(url.path)
            throw posixError()
        }
    }

    private func syncParentDirectory() throws {
        let descriptor = open(url.deletingLastPathComponent().path, O_RDONLY)
        guard descriptor >= 0 else { throw posixError() }
        defer { _ = close(descriptor) }
        guard fsync(descriptor) == 0 else { throw posixError() }
    }

    private func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    @discardableResult
    private func pathExistsWithoutFollowingSymlinks(
        at candidate: URL,
        error: SessionStateStoreError
    ) throws -> Bool {
        var info = stat()
        guard lstat(candidate.path, &info) == 0 else {
            if errno == ENOENT { return false }
            throw error
        }
        if (info.st_mode & S_IFMT) == S_IFLNK {
            throw error
        }
        return true
    }
}
