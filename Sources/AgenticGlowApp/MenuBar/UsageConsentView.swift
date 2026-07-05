import SwiftUI

struct UsageConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var codexEnabled: Bool
    @State private var claudeEnabled: Bool
    @State private var claudeSessionCookie = ""
    @State private var errorMessage: String?
    private let claudeCredentialConfigured: Bool
    let apply: (Bool, Bool, String) throws -> Void

    init(
        codexEnabled: Bool,
        claudeEnabled: Bool,
        claudeCredentialConfigured: Bool,
        apply: @escaping (Bool, Bool, String) throws -> Void
    ) {
        _codexEnabled = State(initialValue: codexEnabled)
        _claudeEnabled = State(initialValue: claudeEnabled)
        self.claudeCredentialConfigured = claudeCredentialConfigured
        self.apply = apply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Access").font(.title2.weight(.semibold))
            Text("AgenticGlow can request subscription allowance directly using credentials already managed on this Mac.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Requests go only to providers you select.")
                .font(.callout.weight(.medium))
            VStack(alignment: .leading, spacing: 8) {
                Toggle("OpenAI Codex", isOn: $codexEnabled)
                Toggle("Anthropic Claude", isOn: $claudeEnabled)
                if claudeEnabled {
                    SecureField("Paste full claude.ai cookie", text: $claudeSessionCookie)
                        .accessibilityLabel("Claude session cookie")
                    Text(
                        claudeCredentialConfigured && claudeSessionCookie.isEmpty
                            ? "An existing Keychain cookie will be kept."
                            : "Copy the Cookie request header from claude.ai Settings > Usage."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("No AgenticGlow server", systemImage: "lock.shield")
                Label("No analytics or telemetry", systemImage: "chart.bar.xaxis")
                Label("Claude cookie stored only in Keychain", systemImage: "key")
                Text("Unofficial Claude connection")
                    .fontWeight(.semibold)
                Text("Anthropic does not provide a supported public usage API. This private claude.ai connection may stop working if Anthropic changes it.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Button("Not Now") { dismiss() }
                Spacer()
                Button("Enable Usage") {
                    do {
                        if claudeEnabled,
                           !claudeCredentialConfigured,
                           claudeSessionCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            throw ClaudeCredentialError(
                                message: "Paste the full Claude session cookie."
                            )
                        }
                        try apply(codexEnabled, claudeEnabled, claudeSessionCookie)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Usage Access")
    }
}
