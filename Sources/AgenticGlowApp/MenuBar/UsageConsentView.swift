import SwiftUI

struct UsageConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var codexEnabled: Bool
    @State private var claudeEnabled: Bool
    @State private var cursorEnabled: Bool
    @State private var claudeSessionCookie = ""
    @State private var cursorSessionCookie = ""
    @State private var errorMessage: String?
    private let claudeCredentialConfigured: Bool
    private let cursorCredentialConfigured: Bool
    let apply: (UsageConsentSelection) throws -> Void

    init(
        codexEnabled: Bool,
        claudeEnabled: Bool,
        cursorEnabled: Bool,
        claudeCredentialConfigured: Bool,
        cursorCredentialConfigured: Bool,
        apply: @escaping (UsageConsentSelection) throws -> Void
    ) {
        _codexEnabled = State(initialValue: codexEnabled)
        _claudeEnabled = State(initialValue: claudeEnabled)
        _cursorEnabled = State(initialValue: cursorEnabled)
        self.claudeCredentialConfigured = claudeCredentialConfigured
        self.cursorCredentialConfigured = cursorCredentialConfigured
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
                Toggle("Cursor", isOn: $cursorEnabled)
                if cursorEnabled {
                    SecureField("Paste full cursor.com cookie", text: $cursorSessionCookie)
                        .accessibilityLabel("Cursor session cookie")
                        .accessibilityIdentifier("AgenticGlow.UsageAccess.CursorCookie")
                    Text(
                        cursorCredentialConfigured && cursorSessionCookie.isEmpty
                            ? "An existing Keychain cookie will be kept."
                            : "Copy the Cookie request header from cursor.com Dashboard."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text("Shows Cursor Models and Other Models as separate allowances.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("No AgenticGlow server", systemImage: "lock.shield")
                Label("No analytics or telemetry", systemImage: "chart.bar.xaxis")
                Label("Cookies stored only in Keychain", systemImage: "key")
                Text("Unofficial provider connections")
                    .fontWeight(.semibold)
                Text("Anthropic does not provide a supported public usage API. This private claude.ai connection may stop working if Anthropic changes it.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Cursor does not provide an individual usage API. AgenticGlow reads the same private endpoint the Cursor dashboard uses, and may need maintenance if Cursor changes it. AgenticGlow never takes this cookie from Cursor or a browser: you paste it here.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("AgenticGlow.UsageAccess.Error")
            }
            HStack {
                Button("Not Now") { dismiss() }
                Spacer()
                Button("Enable Usage") { submit() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Usage Access")
    }

    private func submit() {
        do {
            if claudeEnabled, !claudeCredentialConfigured, isBlank(claudeSessionCookie) {
                throw SessionCredentialError(message: "Paste the full Claude session cookie.")
            }
            if cursorEnabled, !cursorCredentialConfigured, isBlank(cursorSessionCookie) {
                throw SessionCredentialError(message: "Paste the full Cursor session cookie.")
            }
            try apply(
                UsageConsentSelection(
                    codex: codexEnabled,
                    claude: claudeEnabled,
                    cursor: cursorEnabled,
                    claudeCookie: claudeSessionCookie,
                    cursorCookie: cursorSessionCookie
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// What the user chose in Usage Access. Cookies live here only for the
/// hop between the sheet and the Keychain write; nothing retains them.
struct UsageConsentSelection {
    let codex: Bool
    let claude: Bool
    let cursor: Bool
    let claudeCookie: String
    let cursorCookie: String
}
