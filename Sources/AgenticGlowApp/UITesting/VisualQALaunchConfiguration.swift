import Foundation

struct VisualQALaunchConfiguration: Equatable {
    enum Appearance: String {
        case light
        case dark
    }

    let appearance: Appearance
    let glassClarity: Double

    init?(arguments: [String]) {
        guard arguments.contains("--visual-qa") else { return nil }

        appearance = Self.value(after: "--visual-qa-appearance", in: arguments)
            .flatMap(Appearance.init(rawValue:)) ?? .dark

        let requestedClarity = Self.value(
            after: "--visual-qa-glass-clarity",
            in: arguments
        ).flatMap(Double.init) ?? 0
        glassClarity = min(max(requestedClarity, 0), 1)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
