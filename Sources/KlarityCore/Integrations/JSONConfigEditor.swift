import Darwin
import Foundation

public final class JSONConfigEditor {
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
        let parent = url.deletingLastPathComponent()
        guard try pathExistsWithoutFollowingSymlinks(at: parent, error: .unsafeDirectory) else {
            return nil
        }
        try validateDirectory(at: parent)

        guard try pathExistsWithoutFollowingSymlinks(at: url, error: .unsafeFile) else {
            return nil
        }
        try validateFile(at: url)
        return try decodeObject(Data(contentsOf: url))
    }

    public func mutate(_ change: (inout [String: Any]) throws -> Void) throws {
        let originalData: Data?
        var object: [String: Any]

        if let existing = try readObjectIfPresent() {
            originalData = try Data(contentsOf: url)
            object = existing
        } else {
            originalData = nil
            object = [:]
        }

        let originalObject = object
        try change(&object)
        guard JSONSerialization.isValidJSONObject(object) else {
            throw CocoaError(.propertyListWriteInvalid)
        }
        if NSDictionary(dictionary: originalObject).isEqual(to: object) {
            return
        }

        try prepareParentDirectory()
        if let originalData {
            try writeFirstBackupIfNeeded(originalData)
        }

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) + Data("\n".utf8)
        _ = try decodeObject(data)
        try atomicallyReplace(with: data)
    }

    private func decodeObject(_ data: Data) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return object
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

    private func writeFirstBackupIfNeeded(_ data: Data) throws {
        let directory = url.deletingLastPathComponent()
        let prefix = "\(url.lastPathComponent)."
        let existing = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).contains {
            $0.lastPathComponent.hasPrefix(prefix)
                && $0.lastPathComponent.hasSuffix(".bak-klarity")
        }
        guard !existing else { return }

        let backup = directory.appendingPathComponent(
            "\(prefix)\(UUID().uuidString).bak-klarity"
        )
        try data.write(to: backup, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
    }

    private func atomicallyReplace(with data: Data) throws {
        let directory = url.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(
            ".\(url.lastPathComponent).\(UUID().uuidString).tmp"
        )
        var temporaryExists = false
        defer {
            if temporaryExists {
                try? fileManager.removeItem(at: temporary)
            }
        }

        try data.write(to: temporary, options: [.atomic])
        temporaryExists = true
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)

        if try pathExistsWithoutFollowingSymlinks(at: url, error: .unsafeFile) {
            try validateFile(at: url)
            _ = try fileManager.replaceItemAt(url, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: url)
        }
        temporaryExists = false
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
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
