import AppKit
import SwiftUI
import AgenticGlowCore

/// Keeps the Keychain out of the view. `save` returns an error message to
/// show, or nil on success, so the view never handles a thrown error and
/// the recipient value never travels through a preference object.
struct MessagesRecipientBinding {
    var load: () -> String?
    var save: (String) -> String?

    init(
        load: @escaping () -> String? = { nil },
        save: @escaping (String) -> String? = { _ in nil }
    ) {
        self.load = load
        self.save = save
    }
}

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    @Bindable var updates: UpdateViewModel
    let launchAtLogin: LaunchAtLoginServicing
    let openIntegrations: () -> Void
    let serviceStatusChanged: (Bool) -> Void
    let notificationsDenied: () async -> Bool
    let settingsPresentationChanged: (Bool) -> Void
    let registerGlobalShortcut: (GlobalShortcut) -> GlobalShortcutRegistrationResult
    let messagesRecipient: MessagesRecipientBinding
    let sendTestUsageResetAlert: () -> Void
    @State private var launchAtLoginEnabled: Bool
    @State private var showsDeniedHint = false
    @State private var isRecordingShortcut = false
    @State private var shortcutAlert: ShortcutAlert?
    /// Loaded in `.task`, never in `init`. SwiftUI re-initializes this view
    /// whenever an observed preference changes, so reading the Keychain from
    /// the initializer meant a synchronous Keychain hit on the main thread
    /// every time any toggle in this window moved.
    @State private var recipient = ""
    @State private var recipientError: String?
    @State private var confirmsTestAlert = false
    /// What is actually in the Keychain, as opposed to what is currently
    /// typed. Messages delivery uses the stored value, so the two drifting
    /// apart is the difference between an alert arriving and vanishing.
    @State private var storedRecipient = ""
    @FocusState private var recipientFocused: Bool

    init(
        preferences: PreferencesStore,
        updates: UpdateViewModel,
        launchAtLogin: LaunchAtLoginServicing,
        openIntegrations: @escaping () -> Void,
        serviceStatusChanged: @escaping (Bool) -> Void = { _ in },
        notificationsDenied: @escaping () async -> Bool = { false },
        settingsPresentationChanged: @escaping (Bool) -> Void = { _ in },
        registerGlobalShortcut: @escaping (GlobalShortcut) -> GlobalShortcutRegistrationResult = { _ in .unavailable },
        messagesRecipient: MessagesRecipientBinding = MessagesRecipientBinding(),
        sendTestUsageResetAlert: @escaping () -> Void = {}
    ) {
        self.preferences = preferences
        self.updates = updates
        self.launchAtLogin = launchAtLogin
        self.openIntegrations = openIntegrations
        self.serviceStatusChanged = serviceStatusChanged
        self.notificationsDenied = notificationsDenied
        self.settingsPresentationChanged = settingsPresentationChanged
        self.registerGlobalShortcut = registerGlobalShortcut
        self.messagesRecipient = messagesRecipient
        self.sendTestUsageResetAlert = sendTestUsageResetAlert
        _launchAtLoginEnabled = State(initialValue: launchAtLogin.isEnabled)
    }

    var body: some View {
        Form {
            Toggle("Show elapsed turn timer", isOn: $preferences.showTimer)
            Section("Appearance") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Menu bar icon", selection: $preferences.menuBarIconStyle) {
                        Text("Color").tag(MenuBarIconStyle.color)
                        Text("Monochrome").tag(MenuBarIconStyle.monochrome)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("AgenticGlow.MenuBarIconStyle")
                    Text("Monochrome matches the menu bar's own black or white.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Glass Clarity")
                        Spacer()
                        Text(preferences.glassClarity, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $preferences.glassClarity, in: 0...1)
                        .accessibilityLabel("Glass Clarity")
                        .accessibilityValue(Text(
                            verbatim: "\(Int((preferences.glassClarity * 100).rounded())) percent"
                        ))
                        .accessibilityHint("Higher clarity reveals more of the background.")
                        .accessibilityIdentifier("AgenticGlow.GlassClarity")
                    Text("Higher clarity reveals more of the background through the popover.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Keyboard Shortcut") {
                GlobalShortcutRecorder(
                    shortcut: preferences.globalShortcut,
                    isRecording: $isRecordingShortcut,
                    capture: updateGlobalShortcut
                )
                Text("Shows the live AgenticGlow menu bar. Click the shortcut, then press a Command-key combination.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Notify when an agent needs permission", isOn: $preferences.notifyPermission)
                Toggle("Notify when usage runs low", isOn: $preferences.notifyQuotaLow)
                if showsDeniedHint {
                    Text("Notifications are turned off for AgenticGlow in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            usageResetSection
            Section {
                Toggle("Show provider incidents", isOn: Binding(
                    get: { preferences.serviceStatusEnabled },
                    set: { value in
                        preferences.serviceStatusEnabled = value
                        serviceStatusChanged(value)
                    }
                ))
                Text("Checks the public Anthropic, OpenAI, and Cursor status pages when you open AgenticGlow. Off by default. No account data is sent.")
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
            storedRecipient = messagesRecipient.load() ?? ""
            recipient = storedRecipient
        }
        .onDisappear {
            settingsPresentationChanged(false)
        }
        .alert(item: $shortcutAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var usageResetSection: some View {
        Section("Usage Reset Alerts") {
            Toggle("Notify when usage resets", isOn: $preferences.notifyUsageReset)
            Text("Alerts only after AgenticGlow sees usage actually return, not when a reset time passes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(AgentProvider.allCases, id: \.rawValue) { provider in
                Toggle(provider.displayName, isOn: Binding(
                    get: { preferences.usageResetProviders.contains(provider) },
                    set: { isOn in
                        if isOn {
                            preferences.usageResetProviders.insert(provider)
                        } else {
                            preferences.usageResetProviders.remove(provider)
                        }
                    }
                ))
                .disabled(!preferences.notifyUsageReset)
                .accessibilityIdentifier("AgenticGlow.UsageReset.\(provider.rawValue)")
            }

            Toggle("macOS notification", isOn: $preferences.usageResetNativeNotification)
                .disabled(!preferences.notifyUsageReset)
            Toggle("Messages", isOn: $preferences.usageResetMessages)
                .disabled(!preferences.notifyUsageReset)
                .accessibilityIdentifier("AgenticGlow.UsageReset.Messages")

            if preferences.usageResetMessages {
                VStack(alignment: .leading, spacing: 6) {
                    // An explicit bordered field with the text as a prompt.
                    // A titled TextField in a grouped Form splits into an
                    // external label plus a trailing input, and nested in
                    // this VStack the input collapsed to zero width, so the
                    // row rendered as a label with nowhere to type.
                    TextField(
                        "",
                        text: $recipient,
                        prompt: Text("Phone number or Apple Account")
                    )
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .accessibilityLabel("Messages recipient")
                    .accessibilityIdentifier("AgenticGlow.UsageReset.Recipient")
                    .focused($recipientFocused)
                    .onSubmit(saveRecipient)
                    // Clicking away used to discard the typed value in
                    // silence, leaving Messages enabled with no destination.
                    .onChange(of: recipientFocused) { _, focused in
                        if !focused { saveRecipient() }
                    }
                    Button("Save Recipient", action: saveRecipient)
                    if let recipientError {
                        Text(recipientError)
                            .font(.caption)
                            .foregroundStyle(Color(nsColor: .systemRed))
                    } else if storedRecipient.isEmpty {
                        Label(
                            "No recipient saved yet, so no message will be sent.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .systemOrange))
                        .accessibilityIdentifier("AgenticGlow.UsageReset.NoRecipient")
                    } else if recipient.trimmed != storedRecipient {
                        Text("Unsaved change. Click Save Recipient to use it.")
                            .font(.caption)
                            .foregroundStyle(Color(nsColor: .systemOrange))
                    }
                    Text("Stored in your Keychain, never in a settings file. The first message asks macOS for permission to control Messages.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Send Test Alert") {
                if sendsTestMessage {
                    confirmsTestAlert = true
                } else {
                    sendTestUsageResetAlert()
                }
            }
            .disabled(!preferences.notifyUsageReset || !hasUsageResetChannel)
            .accessibilityIdentifier("AgenticGlow.UsageReset.Test")
            // Attached to the button, not to the Form. Stacking this on the
            // same view as the shortcut alert meant only one of the two
            // presentations ever registered, so this dialog never appeared
            // and the button did nothing at all.
            .confirmationDialog(
                "Send a test message?",
                isPresented: $confirmsTestAlert,
                titleVisibility: .visible
            ) {
                Button("Send Test Alert") { sendTestUsageResetAlert() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A real iMessage will be sent to your saved recipient.")
            }
        }
    }

    /// Only warn about a real message when one will actually be sent. With
    /// Messages on but nothing stored, the test is native-only and a
    /// confirmation would be a lie.
    private var sendsTestMessage: Bool {
        preferences.usageResetMessages && !storedRecipient.isEmpty
    }

    /// With no channel on there is nothing for a test to exercise, and a
    /// button that silently does nothing is worse than a disabled one.
    private var hasUsageResetChannel: Bool {
        preferences.usageResetNativeNotification || preferences.usageResetMessages
    }

    private func saveRecipient() {
        let value = recipient.trimmed
        guard value != storedRecipient else { return }
        recipientError = messagesRecipient.save(value)
        if recipientError == nil {
            storedRecipient = value
            recipient = value
        }
    }

    private func updateGlobalShortcut(_ shortcut: GlobalShortcut) {
        switch registerGlobalShortcut(shortcut) {
        case .registered:
            break
        case .unavailable:
            shortcutAlert = ShortcutAlert(
                title: "Shortcut Unavailable",
                message: "\(shortcut.displayName) is already used by macOS or another app. Your current shortcut is unchanged."
            )
        case .invalid:
            shortcutAlert = ShortcutAlert(
                title: "Choose a Different Shortcut",
                message: "Use Command with a key other than Q or W. Your current shortcut is unchanged."
            )
        }
    }
}

private struct ShortcutAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct GlobalShortcutRecorder: NSViewRepresentable {
    let shortcut: GlobalShortcut
    @Binding var isRecording: Bool
    let capture: (GlobalShortcut) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(isRecording: $isRecording, capture: capture) }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton(title: shortcut.displayName, target: context.coordinator, action: #selector(Coordinator.beginRecording(_:)))
        button.coordinator = context.coordinator
        button.setAccessibilityIdentifier("AgenticGlow.GlobalShortcut")
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.title = isRecording ? "Press shortcut…" : shortcut.displayName
    }

    @MainActor
    final class Coordinator: NSObject {
        @Binding private var isRecording: Bool
        private let capture: (GlobalShortcut) -> Void

        init(isRecording: Binding<Bool>, capture: @escaping (GlobalShortcut) -> Void) {
            _isRecording = isRecording
            self.capture = capture
        }

        @objc func beginRecording(_ sender: NSButton) {
            isRecording = true
            sender.window?.makeFirstResponder(sender)
        }

        func received(_ shortcut: GlobalShortcut) {
            isRecording = false
            capture(shortcut)
        }
    }
}

private final class ShortcutRecorderButton: NSButton {
    weak var coordinator: GlobalShortcutRecorder.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !modifiers.isEmpty, let key = event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty else {
            NSSound.beep()
            return
        }
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= 256 }
        if modifiers.contains(.shift) { carbonModifiers |= 512 }
        if modifiers.contains(.option) { carbonModifiers |= 2048 }
        if modifiers.contains(.control) { carbonModifiers |= 4096 }
        coordinator?.received(GlobalShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers,
            displayName: modifierDisplayName(modifiers) + key
        ))
    }

    private func modifierDisplayName(_ modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
