import Foundation

/// The one JSON dialect every AgenticGlow file and record uses: seconds
/// since 1970 for dates and sorted keys, so two encodings of equal values
/// are byte-identical. In its own file because the iOS module compiles it
/// without the rest of the event pipeline.
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
