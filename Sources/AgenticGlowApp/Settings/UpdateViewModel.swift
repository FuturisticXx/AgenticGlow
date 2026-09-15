import AppKit
import Foundation
import Observation
import AgenticGlowCore

@MainActor
@Observable
final class UpdateViewModel {
    private let checker: UpdateChecking
    private let defaults: UserDefaults
    var status = "Not checked"
    var availableUpdate: AvailableUpdate?

    init(
        checker: UpdateChecking = GitHubUpdateChecker(),
        defaults: UserDefaults = .standard
    ) {
        self.checker = checker
        self.defaults = defaults
    }

    func check(manual: Bool, automaticEnabled: Bool) async {
        let now = Date()
        let last = defaults.object(forKey: "lastUpdateCheck") as? Date
        if !manual {
            guard automaticEnabled else { return }
            if let last, now.timeIntervalSince(last) < 86_400 { return }
        }

        do {
            let version = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "0.0.0"
            availableUpdate = try await checker.check(
                currentVersion: version,
                enabled: true
            )
            defaults.set(now, forKey: "lastUpdateCheck")
            status = availableUpdate.map { "Version \($0.version) is available" }
                ?? "AgenticGlow is up to date"
        } catch {
            status = manual ? "Could not check for updates" : "Not checked"
        }
    }

    func openAvailableUpdate() {
        guard let url = availableUpdate?.url else { return }
        NSWorkspace.shared.open(url)
    }
}
