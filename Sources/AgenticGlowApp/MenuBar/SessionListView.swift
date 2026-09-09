import AppKit
import AgenticGlowCore
import SwiftUI

struct SessionListView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable var model: AppModel
    @Bindable var preferences: PreferencesStore
    @Bindable var popoverState: PopoverState
    let claudeCredentialStore: any SessionCredentialStoring
    let cursorCredentialStore: any SessionCredentialStoring
    let openIntegrations: () -> Void
    var settingsPresentationChanged: (Bool) -> Void = { _ in }
    @State private var showingUsageConsent = false
    /// Independent of the allowance section's own disclosure state. Neither
    /// control reads or writes the other's flag.
    @State private var isSessionsExpanded = SessionsDisclosure.defaultExpanded
    /// Measured height of the session rows, so the list neither reserves
    /// empty space nor grows without bound.
    @State private var sessionRowsHeight: CGFloat = 0
    private let singleRowHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Service incidents stay visible in either state: they explain a
            // stalled agent and belong with the providers, not the session list.
            incidentContent

            if SessionsDisclosure.showsSessions(expanded: isSessionsExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(summary)
                        .font(.headline)
                        .accessibilityLabel(summary)
                        .accessibilityValue(summary)
                        .accessibilityIdentifier("AgenticGlow.SessionSummary")

                    sessionContent
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            sessionsBoundary
            AllowanceSectionView(
                model: model,
                usageEnabled: usageEnabled,
                isPopoverPresented: popoverState.isPresented,
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
                    Button("Settings…") {
                        settingsPresentationChanged(true)
                        openSettings()
                    }
                    .accessibilityIdentifier("AgenticGlow.SettingsMenuItem")
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
                LiquidGlassSurface(clarity: preferences.glassClarity)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .overlay {
            PopoverAura(active: popoverState.isPresented)
        }
        .onChange(of: popoverState.isPresented) { _, isPresented in
            if !isPresented { isSessionsExpanded = SessionsDisclosure.defaultExpanded }
        }
        .sheet(isPresented: $showingUsageConsent) {
            UsageConsentView(
                codexEnabled: preferences.codexUsageEnabled,
                claudeEnabled: preferences.claudeUsageEnabled,
                cursorEnabled: preferences.cursorUsageEnabled,
                claudeCredentialConfigured: (try? claudeCredentialStore.load()) != nil,
                cursorCredentialConfigured: (try? cursorCredentialStore.load()) != nil,
                apply: applyUsageConsent
            )
        }
    }

    /// The Sessions/Allowance boundary: the chevron sits on the divider it
    /// shares with the allowance section, so collapsing leaves one clean line
    /// with a small affordance above it rather than a gap between two rules.
    /// Presentation only, so the click triggers no scan, fetch, or reload.
    private var sessionsBoundary: some View {
        VStack(spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSessionsExpanded.toggle()
                }
            } label: {
                Image(systemName: SessionsDisclosure.symbolName(expanded: isSessionsExpanded))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                SessionsDisclosure.accessibilityLabel(expanded: isSessionsExpanded)
            )
            .accessibilityIdentifier("AgenticGlow.SessionsDisclosure")

            Divider()
        }
    }

    /// One quiet line per provider with an active status-page incident, so a
    /// stalled agent can be blamed on the service instead of the setup.
    @ViewBuilder
    private var incidentContent: some View {
        ForEach(AgentProvider.allCases, id: \.rawValue) { provider in
            if case let .incident(description) = model.serviceStatus(for: provider) {
                Label(
                    "\(providerName(provider)): \(description)",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(providerName(provider)) service incident. \(description)")
                .accessibilityIdentifier("AgenticGlow.Incident.\(provider.rawValue)")
            }
        }
    }

    private func providerName(_ provider: AgentProvider) -> String {
        provider.displayName
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
                description: Text("Start Codex, Claude, or Cursor to see live status.")
            )
        } else {
            // The scroll view reports no height of its own, so the list is
            // sized from its measured rows and capped: a short list leaves no
            // empty band above the boundary chevron, a long one still scrolls.
            ScrollView {
                sessionRows.background(rowHeightReader)
            }
            .frame(height: min(max(sessionRowsHeight, singleRowHeight), 300))
        }
    }

    private var sessionRows: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            let groups = WorkGrouping.groups(from: model.resolved.sessions)
            ForEach(WorkGrouping.orderedSessions(from: model.resolved.sessions)) { session in
                SessionRowView(
                    session: session,
                    workTitle: workTitle(for: session, in: groups),
                    action: { model.activate(session) },
                    onRemove: { model.removeSession(session) }
                )
            }
        }
    }

    /// Reads the rendered height of the rows. They lay out at their natural
    /// height inside the scroll view regardless of the frame applied to it,
    /// so this measures the content even before the first cycle settles.
    private var rowHeightReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { sessionRowsHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, height in
                    sessionRowsHeight = height
                }
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
        if preferences.cursorUsageEnabled {
            Text("Cursor: \(detail(for: .cursor))")
        }
    }

    private var usageEnabled: Bool {
        preferences.codexUsageEnabled
            || preferences.claudeUsageEnabled
            || preferences.cursorUsageEnabled
    }

    private var summary: String {
        WorkSummaryLine.popover(resolved: model.resolved)
    }

    private func workTitle(for session: SessionSnapshot, in groups: [WorkGrouping.Group]) -> String {
        groups.first { group in
            group.sessions.contains { $0.id == session.id }
        }?.presentation.displayName ?? WorkTitle.display(session.projectName)
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

    private func applyUsageConsent(_ selection: UsageConsentSelection) throws {
        try store(
            cookie: selection.claudeCookie,
            enabled: selection.claude,
            in: claudeCredentialStore,
            missingMessage: "Paste the full Claude session cookie."
        )
        try store(
            cookie: selection.cursorCookie,
            enabled: selection.cursor,
            in: cursorCredentialStore,
            missingMessage: "Paste the full Cursor session cookie."
        )
        preferences.codexUsageEnabled = selection.codex
        preferences.claudeUsageEnabled = selection.claude
        preferences.cursorUsageEnabled = selection.cursor
        Task {
            await model.setUsageEnabled(selection.codex, provider: .codex)
            await model.setUsageEnabled(selection.claude, provider: .claude)
            await model.setUsageEnabled(selection.cursor, provider: .cursor)
        }
    }

    /// Turning a provider off removes its cookie rather than leaving it
    /// in the Keychain unused. A newly pasted cookie replaces whatever is
    /// stored; an empty field keeps the existing one.
    private func store(
        cookie: String,
        enabled: Bool,
        in credentialStore: any SessionCredentialStoring,
        missingMessage: String
    ) throws {
        guard enabled else {
            try credentialStore.delete()
            return
        }
        if !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try credentialStore.save(cookie)
        } else if try credentialStore.load() == nil {
            throw SessionCredentialError(message: missingMessage)
        }
    }
}

/// A soft illuminated edge in the app icon's palette. Rendered as light
/// diffused into the popover material: one slowly rotating angular gradient
/// masked twice, as a wide blurred halo and as a thin filament on the outline.
private struct PopoverAura: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                ConcentricRectangle()
                    .stroke(Color.white, lineWidth: width)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white, lineWidth: width)
            }
            #else
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white, lineWidth: width)
            #endif
        }
        .padding(width / 2)
        .blur(radius: blur)
    }

    private var stops: [Gradient.Stop] {
        let azure = Color(red: 0.15, green: 0.44, blue: 0.95)
        let ice = Color(red: 0.35, green: 0.60, blue: 0.98)
        let gold = Color(red: 0.90, green: 0.58, blue: 0.16)
        let green = Color(red: 0.10, green: 0.62, blue: 0.40)
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

    private let haloOpacity = 0.55
    private let midOpacity = 0.50
    private let filamentOpacity = 0.90

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
