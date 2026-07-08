import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    @Bindable var updates: UpdateViewModel
    let launchAtLogin: LaunchAtLoginServicing
    let openIntegrations: () -> Void
    let serviceStatusChanged: (Bool) -> Void
    let notificationsDenied: () async -> Bool
    @State private var launchAtLoginEnabled: Bool
    @State private var showsDeniedHint = false

    init(
        preferences: PreferencesStore,
        updates: UpdateViewModel,
        launchAtLogin: LaunchAtLoginServicing,
        openIntegrations: @escaping () -> Void,
        serviceStatusChanged: @escaping (Bool) -> Void = { _ in },
        notificationsDenied: @escaping () async -> Bool = { false }
    ) {
        self.preferences = preferences
        self.updates = updates
        self.launchAtLogin = launchAtLogin
        self.openIntegrations = openIntegrations
        self.serviceStatusChanged = serviceStatusChanged
        self.notificationsDenied = notificationsDenied
        _launchAtLoginEnabled = State(initialValue: launchAtLogin.isEnabled)
    }

    var body: some View {
        Form {
            Toggle("Show elapsed turn timer", isOn: $preferences.showTimer)
            Section {
                Toggle("Notify when an agent needs permission", isOn: $preferences.notifyPermission)
                Toggle("Notify when usage runs low", isOn: $preferences.notifyQuotaLow)
                if showsDeniedHint {
                    Text("Notifications are turned off for AgenticGlow in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Show provider incidents", isOn: Binding(
                    get: { preferences.serviceStatusEnabled },
                    set: { value in
                        preferences.serviceStatusEnabled = value
                        serviceStatusChanged(value)
                    }
                ))
                Text("Checks the public Anthropic and OpenAI status pages when you open AgenticGlow. Off by default. No account data is sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle("Check GitHub for updates automatically", isOn: $preferences.automaticUpdateChecks)
            Toggle("Enable sanitized local diagnostics", isOn: $preferences.diagnosticsEnabled)
            Toggle("Launch AgenticGlow at login", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { value in
                    do {
                        try launchAtLogin.setEnabled(value)
                        launchAtLoginEnabled = value
                    } catch {
                        launchAtLoginEnabled = launchAtLogin.isEnabled
                    }
                }
            ))
            HStack {
                Button("Check for Updates") {
                    Task {
                        await updates.check(
                            manual: true,
                            automaticEnabled: preferences.automaticUpdateChecks
                        )
                    }
                }
                Text(updates.status).foregroundStyle(.secondary)
                if updates.availableUpdate != nil {
                    Button("Open Release", action: updates.openAvailableUpdate)
                }
            }
            Button("Manage Integrations", action: openIntegrations)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520)
        .task {
            showsDeniedHint = await notificationsDenied()
        }
    }
}
