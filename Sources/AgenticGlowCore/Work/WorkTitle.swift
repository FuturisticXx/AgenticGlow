import Foundation

/// User-facing work titles. Raw folder names and identity values stay unchanged.
public enum WorkTitle {
    /// Title-case a machine slug. Names that already look human stay exact.
    /// A trailing 6-8 character hex token is treated as a generated uniqueness
    /// suffix and omitted unless `keepGeneratedSuffix` is true.
    public static func display(_ raw: String, keepGeneratedSuffix: Bool = false) -> String {
        guard isMachineSlug(raw) else { return raw }
        var tokens = raw.split(separator: "-").map(String.init)
        var suffix: String?
        if let last = tokens.last, isGeneratedHexSuffix(last) {
            suffix = last
            tokens.removeLast()
        }
        let titled = tokens.map(titleToken)
        if keepGeneratedSuffix, let suffix {
            return (titled + [suffix]).joined(separator: " ")
        }
        return titled.joined(separator: " ")
    }

    /// Stem used to decide whether a generated suffix would collide.
    static func stem(_ raw: String) -> String {
        guard isMachineSlug(raw) else { return raw }
        var tokens = raw.split(separator: "-").map(String.init)
        if let last = tokens.last, isGeneratedHexSuffix(last) {
            tokens.removeLast()
        }
        return tokens.joined(separator: "-")
    }

    private static func isMachineSlug(_ raw: String) -> Bool {
        guard raw.contains("-") else { return false }
        guard !raw.contains(where: \.isUppercase) else { return false }
        guard !raw.contains(where: \.isWhitespace) else { return false }
        return true
    }

    private static func isGeneratedHexSuffix(_ token: String) -> Bool {
        guard token.count >= 6, token.count <= 8 else { return false }
        guard token.allSatisfy(\.isHexDigit) else { return false }
        return token.contains(where: { $0.isHexLetter })
    }

    private static func titleToken(_ token: String) -> String {
        guard let first = token.first else { return token }
        if first.isNumber { return token }
        return first.uppercased() + token.dropFirst()
    }
}

private extension Character {
    var isHexLetter: Bool {
        ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
