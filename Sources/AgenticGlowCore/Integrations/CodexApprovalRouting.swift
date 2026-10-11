import Foundation

/// Decides whether a Codex approval request will be answered by the user.
///
/// Codex runs `PermissionRequest` hooks in its approval path before choosing
/// a reviewer, so the hook fires both when the user will be asked and when
/// Codex's automatic reviewer (`approvals_reviewer = "auto_review"`) will
/// decide on its own. The hook payload does not say which. The turn's
/// reviewer is recorded in the session transcript's newest `turn_context`
/// line, so that is read instead.
///
/// Routing mirrors Codex's `routes_approval_policy_to_guardian`: the
/// automatic reviewer handles a request when the approval policy is
/// `on-request` or granular and the reviewer is `auto_review`. Anything that
/// cannot be read or recognized counts as the user's decision, so a real
/// prompt is never hidden.
public enum CodexApprovalRouting {
    static let chunkSize = 256 * 1024
    static let maximumScanBytes = 32 * 1024 * 1024

    /// Who answers the request, and how that was decided. The raw value is
    /// what the diagnostic log records, so a permission state can be traced
    /// to its evidence without reconstructing the transcript.
    public enum Reviewer: String, Equatable {
        case autoReview = "auto-review"
        case user = "user"
        /// No readable `turn_context`, so the request is treated as the user's.
        case unknown = "user-assumed:no-turn-context"
    }

    public static func reviewer(transcriptPath: String?) -> Reviewer {
        guard let transcriptPath, transcriptPath.hasPrefix("/"),
              let turnContext = lastTurnContext(in: URL(fileURLWithPath: transcriptPath))
        else {
            return .unknown
        }
        return routesToAutoReview(turnContext: turnContext) ? .autoReview : .user
    }

    static func routesToAutoReview(turnContext: [String: Any]) -> Bool {
        let reviewer = turnContext["approvals_reviewer"] as? String
        guard reviewer == "auto_review" || reviewer == "guardian_subagent" else {
            return false
        }
        switch turnContext["approval_policy"] {
        case let policy as String:
            return policy == "on-request"
        case let policy as [String: Any]:
            return policy["granular"] != nil
        default:
            return false
        }
    }

    /// Reads the transcript backwards so a long session costs only the tail
    /// since its newest turn started.
    static func lastTurnContext(in url: URL) -> [String: Any]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }

        let marker = Data(#""type":"turn_context""#.utf8)
        let newline = UInt8(ascii: "\n")
        var end = size
        var carry = Data()
        while end > 0, size - end < UInt64(maximumScanBytes) {
            let start = end > UInt64(chunkSize) ? end - UInt64(chunkSize) : 0
            guard (try? handle.seek(toOffset: start)) != nil,
                  let chunk = try? handle.read(upToCount: Int(end - start))
            else {
                return nil
            }
            var buffer = chunk
            buffer.append(carry)
            // Bytes before the first newline may belong to a line that starts
            // in an earlier chunk, so they wait for the next read.
            var complete = buffer[...]
            if start > 0, let firstBreak = buffer.firstIndex(of: newline) {
                carry = Data(buffer[..<firstBreak])
                complete = buffer[buffer.index(after: firstBreak)...]
            } else if start > 0 {
                carry = buffer
                complete = Data()[...]
            } else {
                carry = Data()
            }
            for line in complete.split(separator: newline).reversed()
            where line.range(of: marker) != nil {
                if let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                   object["type"] as? String == "turn_context",
                   let payload = object["payload"] as? [String: Any] {
                    return payload
                }
            }
            end = start
        }
        return nil
    }
}
