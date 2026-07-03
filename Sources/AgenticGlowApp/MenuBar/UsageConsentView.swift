import SwiftUI

struct UsageConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var codexEnabled: Bool
    @State private var claudeEnabled: Bool
    let apply: (Bool, Bool) -> Void

    init(
        codexEnabled: Bool,
        claudeEnabled: Bool,
        apply: @escaping (Bool, Bool) -> Void
    ) {
        _codexEnabled = State(initialValue: codexEnabled)
        _claudeEnabled = State(initialValue: claudeEnabled)
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
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("No AgenticGlow server", systemImage: "lock.shield")
                Label("No analytics or telemetry", systemImage: "chart.bar.xaxis")
                Label("Credentials are never copied or stored", systemImage: "key.slash")
                Text("Anthropic does not currently provide a supported programmatic allowance connection. Claude remains unavailable if selected.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            HStack {
                Button("Not Now") { dismiss() }
                Spacer()
                Button("Enable Usage") {
                    apply(codexEnabled, claudeEnabled)
                    dismiss()
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
