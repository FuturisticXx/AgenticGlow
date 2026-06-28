import SwiftUI
import KlarityCore

struct SetupView: View {
    @Bindable var claude: SetupViewModel
    @Bindable var codex: SetupViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set up Klarity").font(.largeTitle.bold())
            Text("Klarity stores local status metadata only. It never stores prompts, responses, commands, or tool arguments.")
                .foregroundStyle(.secondary)
            integrationCard("Codex", model: codex)
            integrationCard("Claude", model: claude)
            Text("Codex requires one final step: open Codex, run /hooks, review the Klarity entries, and choose Trust.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done", action: onComplete)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isConfigured)
            }
        }
        .padding(24)
        .frame(minWidth: 520)
    }

    private func integrationCard(_ title: String, model: SetupViewModel) -> some View {
        GroupBox(title) {
            HStack {
                Text(model.detectedVersion.map { "\(statusText(model.phase)) · \($0)" } ?? statusText(model.phase))
                if let lastEventAt = model.lastEventAt {
                    Text("Last event \(lastEventAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Install \(title)") { Task { await model.install() } }
                    .disabled(model.phase == .unavailable || model.phase == .installing)
                Button("Repair \(title)") { Task { await model.repair() } }
                Button("Remove \(title)") { model.remove() }
            }
            .padding(8)
        }
    }

    private func statusText(_ phase: SetupPhase) -> String {
        switch phase {
        case .unavailable: "Not detected"
        case .ready: "Ready to install"
        case .installing: "Installing"
        case .needsTrust: "Installed, trust required"
        case .installed: "Installed"
        case .failed(let message): message
        }
    }

    private var isConfigured: Bool {
        [claude.phase, codex.phase].contains(.installed)
            || [claude.phase, codex.phase].contains(.needsTrust)
    }
}
