import XCTest
@testable import AgenticGlowCore

final class HelperInstallerTests: XCTestCase {
    func testInstallCopiesExecutableAndSetsUserOnlyDirectoryPermissions() throws {
        let root = temporaryDirectory()
        let source = root.appendingPathComponent("source-helper")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.path)
        let destination = root.appendingPathComponent("Application Support/AgenticGlow/bin/agenticglow-event")
        let installer = HelperInstaller(sourceURL: source, destinationURL: destination)

        try installer.install()

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: destination.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, 0o755)
    }

    func testVersionParserExtractsCodexAndClaudeVersions() {
        XCTAssertEqual(
            ProviderVersionDetector.parseVersion("codex-cli 0.133.0"),
            "0.133.0"
        )
        XCTAssertEqual(
            ProviderVersionDetector.parseVersion("2.1.185 (Claude Code)"),
            "2.1.185"
        )
    }
}
