#!/usr/bin/env xcrun swift

import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let master = root.appendingPathComponent("Design/AgenticGlowIcon-1024.png")

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <output-path>\n", stderr)
    exit(64)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], relativeTo: root)
guard FileManager.default.fileExists(atPath: master.path) else {
    fputs("Missing approved icon master: \(master.path)\n", stderr)
    exit(66)
}

if master.standardizedFileURL != output.standardizedFileURL {
    try FileManager.default.copyItem(at: master, to: output)
}
