import SwiftUI
import AgenticGlowCore

struct SetupView: View {
    @Bindable var claude: SetupViewModel
    @Bindable var codex: SetupViewModel
    @Bindable var cursor: SetupViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set up AgenticGlow").font(.largeTitle.bold())
            Text("AgenticGlow stores local status metadata only. It never stores prompts, responses, commands, or tool arguments.")
                .foregroundStyle(.secondary)
            integrationCard("Codex", model: codex)
            integrationCard("Claude", model: claude)
            integrationCard("Cursor", model: cursor)
            Text("Codex requires one final step: open Codex, run /hooks, review the AgenticGlow entries, and choose Trust. Cursor reloads hooks automatically.")
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
        .task {
            async let claudeVersion: Void = claude.detectVersion()
            async let codexVersion: Void = codex.detectVersion()
            async let cursorVersion: Void = cursor.detectVersion()
            _ = await (claudeVersion, codexVersion, cursorVersion)
            claude.syncPhaseFromCurrentStatus()
            codex.syncPhaseFromCurrentStatus()
            cursor.syncPhaseFromCurrentStatus()
        }
    }

    private func integrationCard(_ title: String, model: SetupViewModel) -> some View {
        GroupBox(title) {
            // The `.restarting` phase replaces the whole row rather than
            // sharing space with the "Last event" caption and the three
            // buttons: live testing showed the message alone, squeezed
            // into the leftover space in the normal layout, truncated to
            // an unreadable "Repair s…" — worse than no message at all.
            if model.phase == .restarting {
                HStack {
                    Label(statusText(model.phase), systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(8)
            } else {
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
    }

    private func statusText(_ phase: SetupPhase) -> String {
        switch phase {
        case .unavailable: "Not detected"
        case .ready: "Ready to install"
        case .installing: "Installing"
        case .needsTrust: "Installed, trust required"
        case .installed: "Installed"
        case .restarting: "Repair successful — restarting AgenticGlow…"
        case .failed(let message): message
        }
    }

    private var isConfigured: Bool {
        [claude.phase, codex.phase, cursor.phase].contains(.installed)
            || [claude.phase, codex.phase, cursor.phase].contains(.needsTrust)
    }
}
