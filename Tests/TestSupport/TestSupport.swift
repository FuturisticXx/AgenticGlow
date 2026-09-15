import Foundation

func temporaryDirectory(
    file: StaticString = #filePath,
    line: UInt = #line
) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgenticGlowTests-\(UUID().uuidString)", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    } catch {
        fatalError("Could not create temporary directory at \(file):\(line): \(error)")
    }
}
