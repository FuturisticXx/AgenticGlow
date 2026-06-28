import Darwin
import XCTest
@testable import KlarityCore

final class JSONConfigEditorTests: XCTestCase {
    func testMutatePreservesExistingValuesCreatesOneBackupAndUsesPrivatePermissions() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        let original = Data(#"{"theme":"dark","hooks":{}}"#.utf8)
        try original.write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        let editor = JSONConfigEditor(url: config)

        try editor.mutate { object in
            object["klarity"] = ["enabled": true]
        }
        try editor.mutate { object in
            object["klarity"] = ["enabled": true]
        }

        let object = try jsonObject(at: config)
        XCTAssertEqual(object["theme"] as? String, "dark")
        XCTAssertEqual((object["klarity"] as? [String: Bool])?["enabled"], true)
        XCTAssertEqual(try permissionMode(at: config), 0o600)

        let backups = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("settings.json.")
            && $0.lastPathComponent.hasSuffix(".bak-klarity")
        }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), original)
        XCTAssertEqual(try permissionMode(at: XCTUnwrap(backups.first)), 0o600)
    }

    func testMutateCreatesMissingConfigAndParentWithPrivateFilePermissions() throws {
        let config = privateIntegrationDirectory()
            .appendingPathComponent("provider", isDirectory: true)
            .appendingPathComponent("settings.json")

        try JSONConfigEditor(url: config).mutate { object in
            object["enabled"] = true
        }

        XCTAssertEqual((try jsonObject(at: config))["enabled"] as? Bool, true)
        XCTAssertEqual(try permissionMode(at: config), 0o600)
        XCTAssertEqual(try permissionMode(at: config.deletingLastPathComponent()), 0o700)
    }

    func testMutateAcceptsOwnerControlledReadablePathsAndTightensConfigPermissions() throws {
        let directory = temporaryDirectory()
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: directory.path
        )
        let config = directory.appendingPathComponent("settings.json")
        try Data("{}".utf8).write(to: config)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: config.path
        )

        try JSONConfigEditor(url: config).mutate { $0["enabled"] = true }

        XCTAssertEqual((try jsonObject(at: config))["enabled"] as? Bool, true)
        XCTAssertEqual(try permissionMode(at: config), 0o600)
        XCTAssertEqual(try permissionMode(at: directory), 0o755)
    }

    func testMutateRejectsSymlinkedConfigWithoutChangingTarget() throws {
        let directory = privateIntegrationDirectory()
        let target = directory.appendingPathComponent("target.json")
        let config = directory.appendingPathComponent("settings.json")
        let original = Data(#"{"keep":true}"#.utf8)
        try original.write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        try FileManager.default.createSymbolicLink(at: config, withDestinationURL: target)

        XCTAssertThrowsError(try JSONConfigEditor(url: config).mutate { $0["keep"] = false }) {
            XCTAssertEqual($0 as? SessionStateStoreError, .unsafeFile)
        }
        XCTAssertEqual(try Data(contentsOf: target), original)
    }

    func testMutateRejectsBrokenSymlinkedConfig() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        try FileManager.default.createSymbolicLink(
            at: config,
            withDestinationURL: directory.appendingPathComponent("missing.json")
        )

        XCTAssertThrowsError(try JSONConfigEditor(url: config).mutate { $0["enabled"] = true }) {
            XCTAssertEqual($0 as? SessionStateStoreError, .unsafeFile)
        }
        XCTAssertTrue(pathExistsWithoutFollowingSymlink(at: config))
    }

    func testMutateRejectsSymlinkedParentDirectory() throws {
        let root = privateIntegrationDirectory()
        let target = root.appendingPathComponent("target", isDirectory: true)
        let parent = root.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: parent, withDestinationURL: target)

        XCTAssertThrowsError(
            try JSONConfigEditor(url: parent.appendingPathComponent("settings.json"))
                .mutate { $0["enabled"] = true }
        ) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeDirectory)
        }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: target.appendingPathComponent("settings.json").path
        ))
    }

    func testMutateRejectsConfigWithoutOwnerMetadataAndLeavesItUnchanged() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        let original = Data(#"{"keep":true}"#.utf8)
        try original.write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        let fileManager = MissingConfigOwnerFileManager(paths: [config.path])

        XCTAssertThrowsError(
            try JSONConfigEditor(url: config, fileManager: fileManager)
                .mutate { $0["keep"] = false }
        ) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeFile)
        }
        XCTAssertEqual(try Data(contentsOf: config), original)
    }

    func testMutateRejectsNonObjectJSONWithoutReplacingIt() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        let original = Data("[]".utf8)
        try original.write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)

        XCTAssertThrowsError(
            try JSONConfigEditor(url: config).mutate { $0["enabled"] = true }
        )
        XCTAssertEqual(try Data(contentsOf: config), original)
    }

    func testMutateRejectsMalformedJSONWithoutReplacingIt() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        let original = Data("not-json".utf8)
        try original.write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)

        XCTAssertThrowsError(
            try JSONConfigEditor(url: config).mutate { $0["enabled"] = true }
        )
        XCTAssertEqual(try Data(contentsOf: config), original)
    }

    func testMutateRejectsGroupWritableParentAndConfigFiles() throws {
        let sharedParent = temporaryDirectory()
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o775],
            ofItemAtPath: sharedParent.path
        )
        let parentConfig = sharedParent.appendingPathComponent("settings.json")
        try Data("{}".utf8).write(to: parentConfig)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: parentConfig.path
        )

        XCTAssertThrowsError(
            try JSONConfigEditor(url: parentConfig).mutate { $0["enabled"] = true }
        ) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeDirectory)
        }

        let privateParent = privateIntegrationDirectory()
        let sharedConfig = privateParent.appendingPathComponent("settings.json")
        try Data("{}".utf8).write(to: sharedConfig)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o664],
            ofItemAtPath: sharedConfig.path
        )

        XCTAssertThrowsError(
            try JSONConfigEditor(url: sharedConfig).mutate { $0["enabled"] = true }
        ) { error in
            XCTAssertEqual(error as? SessionStateStoreError, .unsafeFile)
        }
    }

    func testBackupAndReplacementTemporaryFilesArePrivateBeforeChmod() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        try Data(#"{"keep":true}"#.utf8).write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        let fileManager = CreationModeObservingFileManager(configName: config.lastPathComponent)
        let priorMask = umask(0)
        defer { umask(priorMask) }

        try JSONConfigEditor(url: config, fileManager: fileManager)
            .mutate { $0["enabled"] = true }

        XCTAssertEqual(fileManager.observedPreChmodModes.count, 2)
        XCTAssertTrue(fileManager.observedPreChmodModes.allSatisfy { $0 == 0o600 })
    }

    func testMutateRetriesModifiedConfigAndBacksUpExactReplacedVersion() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        try Data(#"{"version":"initial"}"#.utf8).write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        let raced = Data(#"{"version":"raced","external":true}"#.utf8)
        let fileManager = RacingConfigFileManager(
            parentPath: directory.path,
            configURL: config,
            racedData: raced
        )

        try JSONConfigEditor(url: config, fileManager: fileManager)
            .mutate { $0["enabled"] = true }

        let object = try jsonObject(at: config)
        XCTAssertEqual(object["version"] as? String, "raced")
        XCTAssertEqual(object["external"] as? Bool, true)
        XCTAssertEqual(object["enabled"] as? Bool, true)
        let backup = try XCTUnwrap(backupURLs(beside: config).first)
        XCTAssertEqual(try Data(contentsOf: backup), raced)
    }

    func testMutateRetriesConfigCreatedAfterMissingSnapshot() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        let raced = Data(#"{"createdExternally":true}"#.utf8)
        let fileManager = RacingConfigFileManager(
            parentPath: directory.path,
            configURL: config,
            racedData: raced
        )

        try JSONConfigEditor(url: config, fileManager: fileManager)
            .mutate { $0["enabled"] = true }

        let object = try jsonObject(at: config)
        XCTAssertEqual(object["createdExternally"] as? Bool, true)
        XCTAssertEqual(object["enabled"] as? Bool, true)
        let backup = try XCTUnwrap(backupURLs(beside: config).first)
        XCTAssertEqual(try Data(contentsOf: backup), raced)
    }

    func testMutateCleansSecureFilesWhenTemporaryPermissionConfirmationFails() throws {
        let directory = privateIntegrationDirectory()
        let config = directory.appendingPathComponent("settings.json")
        try Data(#"{"keep":true}"#.utf8).write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        let fileManager = FailingTemporaryPermissionFileManager(
            configName: config.lastPathComponent
        )

        XCTAssertThrowsError(
            try JSONConfigEditor(url: config, fileManager: fileManager)
                .mutate { $0["enabled"] = true }
        )

        XCTAssertEqual(try backupURLs(beside: config), [])
        let temporaryFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter {
            $0.lastPathComponent.hasPrefix(".\(config.lastPathComponent).")
                && $0.lastPathComponent.hasSuffix(".tmp")
        }
        XCTAssertEqual(temporaryFiles, [])
        XCTAssertEqual((try jsonObject(at: config))["keep"] as? Bool, true)
    }

    private func jsonObject(at url: URL) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
    }

    private func permissionMode(at url: URL) throws -> UInt16 {
        let permissions = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return UInt16(truncating: permissions) & 0o777
    }

    private func pathExistsWithoutFollowingSymlink(at url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }
}

private final class MissingConfigOwnerFileManager: FileManager {
    private let paths: Set<String>

    init(paths: Set<String>) {
        self.paths = paths
        super.init()
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        var attributes = try super.attributesOfItem(atPath: path)
        if paths.contains(path) {
            attributes.removeValue(forKey: .ownerAccountID)
        }
        return attributes
    }
}

private final class CreationModeObservingFileManager: FileManager {
    let configName: String
    var observedPreChmodModes: [UInt16] = []

    init(configName: String) {
        self.configName = configName
        super.init()
    }

    override func setAttributes(
        _ attributes: [FileAttributeKey: Any],
        ofItemAtPath path: String
    ) throws {
        let name = URL(fileURLWithPath: path).lastPathComponent
        let isBackup = name.hasPrefix("\(configName).") && name.hasSuffix(".bak-klarity")
        let isTemporary = name.hasPrefix(".\(configName).") && name.hasSuffix(".tmp")
        if (isBackup || isTemporary), attributes[.posixPermissions] != nil {
            let current = try super.attributesOfItem(atPath: path)
            let mode = (current[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
            observedPreChmodModes.append(mode & 0o777)
        }
        try super.setAttributes(attributes, ofItemAtPath: path)
    }
}

private final class RacingConfigFileManager: FileManager {
    private let parentPath: String
    private let configURL: URL
    private let racedData: Data
    private var parentReadCount = 0
    private var didRace = false

    init(parentPath: String, configURL: URL, racedData: Data) {
        self.parentPath = parentPath
        self.configURL = configURL
        self.racedData = racedData
        super.init()
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        if path == parentPath {
            parentReadCount += 1
            if parentReadCount == 2, !didRace {
                didRace = true
                try racedData.write(to: configURL)
                try super.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: configURL.path
                )
            }
        }
        return try super.attributesOfItem(atPath: path)
    }
}

private final class FailingTemporaryPermissionFileManager: FileManager {
    private let configName: String

    init(configName: String) {
        self.configName = configName
        super.init()
    }

    override func setAttributes(
        _ attributes: [FileAttributeKey: Any],
        ofItemAtPath path: String
    ) throws {
        let name = URL(fileURLWithPath: path).lastPathComponent
        if name.hasPrefix(".\(configName)."), name.hasSuffix(".tmp") {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.setAttributes(attributes, ofItemAtPath: path)
    }
}
