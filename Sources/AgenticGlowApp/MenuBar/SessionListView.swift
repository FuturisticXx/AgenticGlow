import AppKit
import AgenticGlowCore
import SwiftUI

struct SessionListView: View {
    @Bindable var model: AppModel
    @Bindable var preferences: PreferencesStore
    @Bindable var popoverState: PopoverState
    let claudeCredentialStore: any ClaudeSessionCredentialStoring
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
        .overlay {
            PopoverAura(active: popoverState.isPresented)
        }
        .sheet(isPresented: $showingUsageConsent) {
            UsageConsentView(
                codexEnabled: preferences.codexUsageEnabled,
                claudeEnabled: preferences.claudeUsageEnabled,
                claudeCredentialConfigured: (try? claudeCredentialStore.load()) != nil,
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

    private func applyUsageConsent(codex: Bool, claude: Bool, cookie: String) throws {
        if claude {
            if !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try claudeCredentialStore.save(cookie)
            } else if try claudeCredentialStore.load() == nil {
                throw ClaudeCredentialError(message: "Paste the full Claude session cookie.")
            }
        } else {
            try claudeCredentialStore.delete()
        }
        preferences.codexUsageEnabled = codex
        preferences.claudeUsageEnabled = claude
        Task {
            await model.setUsageEnabled(codex, provider: .codex)
            await model.setUsageEnabled(claude, provider: .claude)
        }
    }
}

/// A soft illuminated edge in the app icon's palette. Rendered as light
/// diffused into the popover material: one slowly rotating angular gradient
/// masked twice, as a wide blurred halo and as a thin filament on the outline.
private struct PopoverAura: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let active: Bool
    @State private var driftAngle = 0.0
    @State private var breath = 0.6

    var body: some View {
        ZStack {
            auraLight
                .mask(edgeBand(width: 14, blur: 12))
                .opacity(haloOpacity * (0.55 + 0.45 * breath))
            auraLight
                .mask(edgeBand(width: 5, blur: 3))
                .opacity(midOpacity * (0.7 + 0.3 * breath))
            auraLight
                .mask(edgeBand(width: 2, blur: 0.8))
                .opacity(filamentOpacity * (0.85 + 0.15 * breath))
        }
        .blendMode(colorScheme == .dark ? .plusLighter : .normal)
        .opacity(active ? 1 : 0)
        .animation(.easeOut(duration: 0.6), value: active)
        .allowsHitTesting(false)
        .task(id: "\(active)-\(reduceMotion)") { updateMotion() }
    }

    private var auraLight: some View {
        Rectangle()
            .fill(AngularGradient(gradient: Gradient(stops: stops), center: .center))
            .scaleEffect(2.5)
            .rotationEffect(.degrees(driftAngle))
    }

    private func edgeBand(width: CGFloat, blur: CGFloat) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                ConcentricRectangle()
                    .stroke(Color.white, lineWidth: width)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white, lineWidth: width)
            }
        }
        .padding(width / 2)
        .blur(radius: blur)
    }

    private var stops: [Gradient.Stop] {
        let azure: Color
        let ice: Color
        let gold: Color
        let green: Color
        if colorScheme == .dark {
            azure = Color(red: 0.42, green: 0.65, blue: 1.00)
            ice = Color(red: 0.75, green: 0.88, blue: 1.00)
            gold = Color(red: 1.00, green: 0.78, blue: 0.48)
            green = Color(red: 0.50, green: 0.87, blue: 0.62)
        } else {
            azure = Color(red: 0.15, green: 0.44, blue: 0.95)
            ice = Color(red: 0.35, green: 0.60, blue: 0.98)
            gold = Color(red: 0.90, green: 0.58, blue: 0.16)
            green = Color(red: 0.10, green: 0.62, blue: 0.40)
        }
        return [
            .init(color: gold, location: 0.00),
            .init(color: azure, location: 0.22),
            .init(color: ice, location: 0.40),
            .init(color: azure, location: 0.55),
            .init(color: green, location: 0.75),
            .init(color: azure, location: 0.90),
            .init(color: gold, location: 1.00)
        ]
    }

    private var haloOpacity: Double { colorScheme == .dark ? 0.65 : 0.55 }
    private var midOpacity: Double { colorScheme == .dark ? 0.60 : 0.50 }
    private var filamentOpacity: Double { colorScheme == .dark ? 0.95 : 0.90 }

    private func updateMotion() {
        var still = Transaction()
        still.disablesAnimations = true
        if active && !reduceMotion {
            withTransaction(still) {
                driftAngle = 0
                breath = 0
            }
            withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                driftAngle = 360
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breath = 1
            }
        } else {
            withTransaction(still) {
                driftAngle = 0
                breath = 0.6
            }
        }
    }
}
