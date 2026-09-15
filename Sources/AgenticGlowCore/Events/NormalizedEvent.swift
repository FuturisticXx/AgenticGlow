import Foundation

public enum EventValidationError: Error, Equatable {
    case unsupportedSchema(Int)
    case invalidSessionID
    case invalidTurnID
    case invalidProjectName
    case invalidWorkingDirectory
    case invalidLabel
    case invalidModel
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
    /// Provider model slug when the hook payload includes one. Optional so
    /// older session files and providers that never report a model still
    /// decode. Never stores prompts, transcripts, or account identifiers.
    public let model: String?

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
        updatedAt: Date,
        model: String? = nil
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
        self.model = model
    }

    public func validate() throws {
        guard schemaVersion == ProductMetadata.schemaVersion else {
            throw EventValidationError.unsupportedSchema(schemaVersion)
        }

        guard Self.isSafeIdentifier(sessionID) else {
            throw EventValidationError.invalidSessionID
        }

        if let turnID, !Self.isSafeIdentifier(turnID) {
            throw EventValidationError.invalidTurnID
        }

        guard !projectName.isEmpty,
              Self.isSafeDisplayText(projectName, maxLength: 128) else {
            throw EventValidationError.invalidProjectName
        }

        guard Self.isSafeDisplayText(label, maxLength: 256) else {
            throw EventValidationError.invalidLabel
        }

        if let model, !Self.isSafeDisplayText(model, maxLength: 64) {
            throw EventValidationError.invalidModel
        }

        guard workingDirectory.hasPrefix("/"),
              workingDirectory.count <= 4096,
              !workingDirectory.contains("\0") else {
            throw EventValidationError.invalidWorkingDirectory
        }
    }

    /// Text that reaches single-line popover and widget copy straight from an
    /// external hook process. Bounded in length, and free of control and
    /// format characters: newlines and carriage returns break the one-line
    /// layout, and a bidi override such as U+202E can silently reverse how a
    /// name renders.
    private static func isSafeDisplayText(_ value: String, maxLength: Int) -> Bool {
        guard value.count <= maxLength else { return false }
        return !value.unicodeScalars.contains { scalar in
            CharacterSet.controlCharacters.contains(scalar)
                || bidiControls.contains(scalar.value)
        }
    }

    /// Explicit bidi overrides and isolates. Listed rather than inferred so
    /// the set does not drift with Foundation's character-set definitions.
    private static let bidiControls: Set<UInt32> = [
        0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
        0x2066, 0x2067, 0x2068, 0x2069
    ]

    private static func isSafeIdentifier(_ value: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return !value.isEmpty
            && value.count <= 128
            && value.unicodeScalars.allSatisfy(allowed.contains)
    }
}

public extension JSONEncoder {
    static var agenticglow: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var agenticglow: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
