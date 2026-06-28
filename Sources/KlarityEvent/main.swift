import Foundation
import KlarityCore

let environment = ProcessInfo.processInfo.environment
let stateDirectory = environment["KLARITY_STATE_DIRECTORY"]
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? FileSessionStateStore.defaultDirectory
let store = FileSessionStateStore(directory: stateDirectory)

let sharedDefaults = UserDefaults(suiteName: ProductMetadata.bundleIdentifier)!
let logger: DiagnosticLogging? = sharedDefaults.bool(forKey: "diagnosticsEnabled")
    ? DiagnosticLogger(
        enabled: true,
        url: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Klarity/klarity.log")
      )
    : nil

let command = KlarityEventCommand(
    store: store,
    processIdentity: { provider, environment in
        ProcessIdentityResolver.live.resolve(provider: provider, environment: environment)
    },
    logger: logger
)
let code = command.run(
    arguments: CommandLine.arguments,
    input: FileHandle.standardInput.readDataToEndOfFile(),
    environment: environment,
    now: Date()
)
exit(code)
