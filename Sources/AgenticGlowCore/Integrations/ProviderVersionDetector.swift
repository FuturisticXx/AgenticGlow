import Foundation

public enum ProviderVersionDetector {
    public static func detect(executableURL: URL) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = output
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let text = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return parseVersion(text)
    }

    public static func parseVersion(_ text: String) -> String? {
        text.split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .first { token in
                token.first?.isNumber == true
                    && token.split(separator: ".").count >= 2
            }?
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
    }
}
