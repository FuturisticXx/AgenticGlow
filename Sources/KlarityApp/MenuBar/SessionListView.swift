import AppKit
import KlarityCore
import SwiftUI

struct SessionListView: View {
    @Bindable var model: AppModel
    let openIntegrations: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.headline)
                .accessibilityIdentifier("Klarity.SessionSummary")

            if let error = model.sessionDataErrorPresentation {
                ContentUnavailableView(
                    error.title,
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.message)
                )
                .accessibilityIdentifier("Klarity.SessionDataError")
            } else if model.resolved.sessions.isEmpty {
                ContentUnavailableView(
                    "No active sessions",
                    systemImage: "circle.hexagongrid",
                    description: Text("Start Codex or Claude to see live status.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(AgentProvider.allCases, id: \.rawValue) { provider in
                            providerSection(provider)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()
            HStack(spacing: 12) {
                Button("Integrations", action: openIntegrations)
                    .accessibilityIdentifier("Klarity.Integrations")
                SettingsLink {
                    Text("Settings")
                }
                .accessibilityIdentifier("Klarity.Settings")
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .accessibilityIdentifier("Klarity.Quit")
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    @ViewBuilder
    private func providerSection(_ provider: AgentProvider) -> some View {
        let sessions = model.resolved.sessions.filter { $0.provider == provider }
        if !sessions.isEmpty {
            Section {
                ForEach(sessions) { session in
                    SessionRowView(session: session) {
                        model.activate(session)
                    }
                }
            } header: {
                Text(provider.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summary: String {
        if model.resolved.activeCount == 1 {
            return "1 active session"
        }
        if model.resolved.activeCount > 1 {
            return "\(model.resolved.activeCount) active sessions"
        }
        let count = model.resolved.sessions.count
        return count == 1 ? "1 session" : "\(count) sessions"
    }
}

private extension AgentProvider {
    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        }
    }
}
