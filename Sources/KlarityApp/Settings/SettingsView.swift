import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    @Bindable var updates: UpdateViewModel
    let launchAtLogin: LaunchAtLoginServicing
    let openIntegrations: () -> Void
    @State private var launchAtLoginEnabled: Bool

    init(
        preferences: PreferencesStore,
        updates: UpdateViewModel,
        launchAtLogin: LaunchAtLoginServicing,
        openIntegrations: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.updates = updates
        self.launchAtLogin = launchAtLogin
        self.openIntegrations = openIntegrations
        _launchAtLoginEnabled = State(initialValue: launchAtLogin.isEnabled)
    }

    var body: some View {
        Form {
            Toggle("Show elapsed turn timer", isOn: $preferences.showTimer)
            Toggle("Check GitHub for updates automatically", isOn: $preferences.automaticUpdateChecks)
            Toggle("Enable sanitized local diagnostics", isOn: $preferences.diagnosticsEnabled)
            Toggle("Launch Klarity at login", isOn: Binding(
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
    }
}
