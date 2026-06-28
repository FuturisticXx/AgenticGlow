import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    @Bindable var updates: UpdateViewModel

    init(
        preferences: PreferencesStore,
        updates: UpdateViewModel
    ) {
        self.preferences = preferences
        self.updates = updates
    }

    var body: some View {
        Form {
            Toggle("Show elapsed turn timer", isOn: $preferences.showTimer)
            Toggle("Check GitHub for updates automatically", isOn: $preferences.automaticUpdateChecks)
            Toggle("Enable sanitized local diagnostics", isOn: $preferences.diagnosticsEnabled)
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
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520)
    }
}
