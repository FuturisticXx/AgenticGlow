import Foundation

/// User-facing model names. Raw slugs stay on the session and in diagnostics.
public enum ModelDisplayName {
    /// Harness prefixes that are never a model family.
    private static let harnessPrefixes: Set<String> = ["cursor"]

    /// Routing and tier tokens that are not useful in compact copy.
    private static let routingSuffixes: Set<String> = [
        "high", "low", "medium", "fast", "xhigh", "max", "thinking", "reasoning", "preview"
    ]

    /// Tokens whose title-case form would be wrong.
    private static let brands: [String: String] = [
        "gpt": "GPT"
    ]

    public static func display(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return display(trimmed)
    }

    public static func display(_ raw: String) -> String {
        guard isMachineSlug(raw) else { return raw }
        var tokens = raw.split(separator: "-").map { String($0).lowercased() }
        while let first = tokens.first, harnessPrefixes.contains(first) {
            tokens.removeFirst()
        }
        while let last = tokens.last, routingSuffixes.contains(last) {
            tokens.removeLast()
        }
        if tokens.isEmpty {
            tokens = raw.split(separator: "-").map { String($0).lowercased() }
                .filter { !harnessPrefixes.contains($0) && !routingSuffixes.contains($0) }
        }
        guard !tokens.isEmpty else { return raw }
        return tokens.map(displayToken).joined(separator: " ")
    }

    private static func isMachineSlug(_ raw: String) -> Bool {
        guard raw.contains("-") else { return false }
        guard !raw.contains(where: \.isUppercase) else { return false }
        guard !raw.contains(where: \.isWhitespace) else { return false }
        return true
    }

    private static func displayToken(_ token: String) -> String {
        if let brand = brands[token] { return brand }
        guard let first = token.first else { return token }
        if first.isNumber { return token }
        return first.uppercased() + token.dropFirst()
    }
}
