import Foundation

/// What one Mac publishes for its iPhone widget: the widget-safe
/// `WidgetSnapshot` it already writes for its own desktop widget, wrapped
/// with just enough to say which Mac observed it and when.
///
/// The snapshot is reused unchanged rather than re-modeled, so the iPhone
/// renders exactly the state the Mac widget renders, and the privacy
/// contract stays the one `docs/privacy.md` already describes for the
/// desktop widget: no prompts, no credentials, no raw provider responses,
/// no working directories. The envelope adds a random per-install Mac
/// identifier (never a serial number or hardware identifier) and the
/// user-visible computer name, which is what the iPhone shows beside the
/// freshness line.
public struct SyncedStateEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    /// Random UUID minted once per Mac install. Keys the per-Mac record so
    /// several Macs can publish side by side without a data model change.
    public let sourceMacID: String
    /// The Mac's user-visible computer name, for the iPhone's footer.
    public let sourceMacName: String
    /// When the Mac last observed this state. Set by the Mac at publish
    /// time, never by the iPhone at fetch time: freshness on the iPhone is
    /// a statement about the Mac, and a successful fetch of an old record
    /// must not make it look current.
    public let observedAt: Date
    public let snapshot: WidgetSnapshot

    public init(
        schemaVersion: Int = SyncedStateEnvelope.currentSchemaVersion,
        sourceMacID: String,
        sourceMacName: String,
        observedAt: Date,
        snapshot: WidgetSnapshot
    ) {
        self.schemaVersion = schemaVersion
        self.sourceMacID = sourceMacID
        self.sourceMacName = sourceMacName
        // Whole seconds only. The wire format carries seconds since 1970
        // as a double, and a fractional Date does not survive that trip
        // bit-for-bit (the reference-date arithmetic rounds), so an
        // envelope read back would compare unequal to the one published.
        // Freshness is judged in minutes; the fraction carries nothing.
        self.observedAt = Date(timeIntervalSince1970: observedAt.timeIntervalSince1970.rounded(.down))
        self.snapshot = snapshot
    }
}

/// Encodes and decodes envelopes for the wire and the App Group cache.
/// Decoding always validates: an envelope that decodes but fails the
/// bounds check is not data this build renders.
public enum SyncedStateCodec {
    /// Well above any real envelope (eight sessions and three providers
    /// encode to a few kilobytes) and well below anything that could be
    /// used to exhaust a widget extension's memory.
    public static let maximumPayloadBytes = 64 * 1024

    public static func encode(_ envelope: SyncedStateEnvelope) throws -> Data {
        try JSONEncoder.agenticglow.encode(envelope)
    }

    public static func decode(_ data: Data) throws -> SyncedStateEnvelope {
        guard data.count <= maximumPayloadBytes else {
            throw SyncedStateValidationError.payloadTooLarge
        }
        let envelope: SyncedStateEnvelope
        do {
            envelope = try JSONDecoder.agenticglow.decode(SyncedStateEnvelope.self, from: data)
        } catch {
            throw SyncedStateValidationError.malformed
        }
        try SyncedStateValidator.validate(envelope)
        return envelope
    }
}
