import Foundation

public enum EventValidationError: Error, Equatable {
    case unsupportedSchema(Int)
    case invalidSessionID
    case invalidProjectName
    case invalidWorkingDirectory
}

public struct NormalizedEvent: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public let provider: AgentProvider
    public let surface: SourceSurface
    public var sessionID: String
    public let turnID: String?
    public let phase: SessionPhase
    public let label: String
    public let toolCategory: ToolCategory?
    public let projectName: String
    public let workingDirectory: String
    public let sourceBundleID: String?
    public let sourceProcessID: Int32?
    public let sourceProcessStartedAt: Date?
    public let turnStartedAt: Date?
    public let updatedAt: Date

    public init(
        schemaVersion: Int,
        provider: AgentProvider,
        surface: SourceSurface,
        sessionID: String,
        turnID: String?,
        phase: SessionPhase,
        label: String,
        toolCategory: ToolCategory?,
        projectName: String,
        workingDirectory: String,
        sourceBundleID: String?,
        sourceProcessID: Int32?,
        sourceProcessStartedAt: Date?,
        turnStartedAt: Date?,
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.provider = provider
        self.surface = surface
        self.sessionID = sessionID
        self.turnID = turnID
        self.phase = phase
        self.label = label
        self.toolCategory = toolCategory
        self.projectName = projectName
        self.workingDirectory = workingDirectory
        self.sourceBundleID = sourceBundleID
        self.sourceProcessID = sourceProcessID
        self.sourceProcessStartedAt = sourceProcessStartedAt
        self.turnStartedAt = turnStartedAt
        self.updatedAt = updatedAt
    }

    public func validate() throws {
        guard schemaVersion == ProductMetadata.schemaVersion else {
            throw EventValidationError.unsupportedSchema(schemaVersion)
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !sessionID.isEmpty,
              sessionID.count <= 128,
              sessionID.unicodeScalars.allSatisfy(allowed.contains) else {
            throw EventValidationError.invalidSessionID
        }

        guard !projectName.isEmpty,
              projectName.count <= 128,
              !projectName.contains("\n") else {
            throw EventValidationError.invalidProjectName
        }

        guard workingDirectory.hasPrefix("/"),
              !workingDirectory.contains("\0") else {
            throw EventValidationError.invalidWorkingDirectory
        }
    }
}

public extension JSONEncoder {
    static var klarity: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var klarity: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
