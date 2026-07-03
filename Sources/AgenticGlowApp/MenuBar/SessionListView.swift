import AppKit
import AgenticGlowCore
import SwiftUI

struct SessionListView: View {
    @Bindable var model: AppModel
    @Bindable var preferences: PreferencesStore
    let openIntegrations: () -> Void
    @State private var showingUsageConsent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.headline)
                .accessibilityLabel(summary)
                .accessibilityValue(summary)
                .accessibilityIdentifier("AgenticGlow.SessionSummary")

            sessionContent

            Divider()
            AllowanceSectionView(
                model: model,
                usageEnabled: usageEnabled,
                enable: { showingUsageConsent = true }
            )

            HStack {
                Spacer()
                Menu {
                    if usageEnabled {
                        Button("Refresh Usage") {
                            Task { await model.refreshUsage(.manual) }
                        }
                    }
                    Button("Usage Access…") { showingUsageConsent = true }
                    usageDetails
                    Divider()
                    Button("Integrations…", action: openIntegrations)
                    SettingsLink { Text("Settings…") }
                    Divider()
                    Button("Quit AgenticGlow") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape")
                        .frame(minWidth: 20, minHeight: 20)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("More options")
                .accessibilityIdentifier("AgenticGlow.More")
            }
        }
        .padding(16)
        .frame(width: 360)
        .background {
            if #available(macOS 26.0, *) {
                Color.clear
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .sheet(isPresented: $showingUsageConsent) {
            UsageConsentView(
                codexEnabled: preferences.codexUsageEnabled,
                claudeEnabled: preferences.claudeUsageEnabled,
                apply: applyUsageConsent
            )
        }
    }

    @ViewBuilder
    private var sessionContent: some View {
        if let error = model.sessionDataErrorPresentation {
            ContentUnavailableView(
                error.title,
                systemImage: "exclamationmark.triangle",
                description: Text(error.message)
            )
            .accessibilityIdentifier("AgenticGlow.SessionDataError")
        } else if model.resolved.sessions.isEmpty {
            ContentUnavailableView(
                "No active sessions",
                systemImage: "circle.hexagongrid",
                description: Text("Start Codex or Claude to see live status.")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(model.resolved.sessions) { session in
                        SessionRowView(session: session) { model.activate(session) }
                    }
                }
            }
            .frame(maxHeight: 300)
            .frame(minHeight: 120)
        }
    }

    @ViewBuilder
    private var usageDetails: some View {
        if preferences.codexUsageEnabled {
            Text("Codex: \(detail(for: .codex))")
        }
        if preferences.claudeUsageEnabled {
            Text("Claude: \(detail(for: .claude))")
        }
    }

    private var usageEnabled: Bool {
        preferences.codexUsageEnabled || preferences.claudeUsageEnabled
    }

    private var summary: String {
        if model.resolved.permissionCount == 1 { return "1 agent needs you" }
        if model.resolved.permissionCount > 1 { return "\(model.resolved.permissionCount) agents need you" }
        if model.resolved.activeCount == 1 { return "1 agent working" }
        if model.resolved.activeCount > 1 { return "\(model.resolved.activeCount) agents working" }
        let count = model.resolved.sessions.count
        return count == 1 ? "1 session" : "\(count) sessions"
    }

    private func detail(for provider: AgentProvider) -> String {
        switch model.allowanceState(for: provider) {
        case .off: "Off"
        case .loading: "Loading"
        case .available(_, .fresh): "Connected"
        case .available(_, .stale): "Cached data"
        case let .unavailable(reason): reason
        }
    }

    private func applyUsageConsent(codex: Bool, claude: Bool) {
        preferences.codexUsageEnabled = codex
        preferences.claudeUsageEnabled = claude
        Task {
            await model.setUsageEnabled(codex, provider: .codex)
            await model.setUsageEnabled(claude, provider: .claude)
        }
    }
}
