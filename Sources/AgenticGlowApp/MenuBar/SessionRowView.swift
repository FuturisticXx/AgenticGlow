import AppKit
import AgenticGlowCore
import SwiftUI

struct SessionRowView: View {
    let session: SessionSnapshot
    var workTitle: String? = nil
    let action: () -> Void
    let onRemove: () -> Void

    private var title: String {
        workTitle ?? WorkTitle.display(session.projectName)
    }

    @State private var isPulsing = false
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let accessibilityValue = Self.accessibilityValue(for: session)
        let row = Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .opacity(isPulsing ? 0.45 : 1)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace.wholeSymbol))
                    .symbolEffect(
                        .bounce,
                        value: SessionRowMotion.iconBounceTrigger(icon: icon, reduceMotion: reduceMotion)
                    )
                    .animation(reduceMotion ? nil : .default, value: icon)
                    .accessibilityHidden(true)
                    .onAppear(perform: updatePulse)
                    .onChange(of: SessionRowMotion.shouldPulse(phase: session.phase, reduceMotion: reduceMotion)) {
                        updatePulse()
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let elapsed = session.elapsedSeconds, session.phase.isActive {
                    Text(Self.format(elapsed))
                        .monospacedDigit()
                        .font(.caption)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("AgenticGlow.Session.\(session.id)")
        .accessibilityLabel(Self.accessibilityLabel(for: session, workTitle: title))
        .accessibilityValue(accessibilityValue ?? "")
        .accessibilityAddTraits(accessibilityValue != nil ? .updatesFrequently : [])
        .accessibilityHint("Activates the source application")

        let header = HStack(spacing: 4) {
            if hasContextActions {
                row.contextMenu {
                    if WorkContextCopy.canReveal(session) {
                        Button("Reveal in Finder", systemImage: "folder") {
                            revealInFinder()
                        }
                        Button("Copy Context", systemImage: "doc.on.doc") {
                            copyContext()
                        }
                    }
                    if isRemovable {
                        Button("Remove", systemImage: "xmark.circle", role: .destructive, action: onRemove)
                    }
                }
            } else {
                row
            }
            expandButton
        }

        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                detailPanel
                    .transition(detailTransition)
            }
        }
    }

    private var expandButton: some View {
        Button {
            withAnimation(.easeOut(duration: SessionRowMotion.detailToggleDuration(reduceMotion: reduceMotion))) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(isExpanded ? .primary : .secondary)
                .rotationEffect(.degrees(SessionRowMotion.chevronRotation(isExpanded: isExpanded)))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("AgenticGlow.Session.\(session.id).Expand")
        .accessibilityLabel(isExpanded ? "Hide details" : "Show details")
    }

    private var detailTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: CGFloat(SessionRowMotion.detailOffset))),
            removal: .opacity
        )
    }

    private var detailPanel: some View {
        let fields = SessionDetailPresentation.detail(for: session, now: Date())
        return VStack(alignment: .leading, spacing: 3) {
            if let started = fields.started {
                detailRow("Started", started)
            }
            detailRow("Current step", fields.currentStep)
            if let model = fields.model {
                detailRow("Model", model)
            }
            detailRow("Surface", fields.surface)
            detailRow("Last updated", fields.lastUpdated)
            if let note = fields.note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 32)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
        .font(.caption2)
    }

    private var isRemovable: Bool {
        [.idle, .disconnected, .completed, .permission, .failed].contains(session.phase)
    }

    private var hasContextActions: Bool {
        isRemovable || WorkContextCopy.canReveal(session)
    }

    private func revealInFinder() {
        guard WorkContextCopy.canReveal(session) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: session.workingDirectory)])
    }

    private func copyContext() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(WorkContextCopy.text(for: session), forType: .string)
    }

    private func updatePulse() {
        let shouldPulse = SessionRowMotion.shouldPulse(phase: session.phase, reduceMotion: reduceMotion)
        guard shouldPulse != isPulsing else { return }
        if shouldPulse {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPulsing = false
            }
        }
    }

    private var detail: String {
        "\(session.label) · \(session.surface.displayName)"
    }

    private var icon: String {
        SessionPhasePresentation.symbolName(for: session.phase, toolCategory: session.toolCategory, in: .row)
    }

    private var color: Color {
        switch session.phase {
        case .thinking, .usingTool: ProviderColor.color(for: session.provider)
        default: SessionPhasePresentation.color(for: session.phase)
        }
    }

    /// `.failed` gets a distinct spoken suffix rather than a rewritten
    /// label, so VoiceOver users can tell a crashed session from one still
    /// working, without losing `session.label`'s last-action text (which
    /// the expanded detail panel also relies on).
    static func accessibilityLabel(for session: SessionSnapshot, workTitle: String? = nil) -> String {
        let title = workTitle ?? WorkTitle.display(session.projectName)
        let base = "\(session.provider.displayName), \(title), \(session.label), \(session.surface.displayName)"
        return session.phase == .failed ? "\(base), stopped while working" : base
    }

    /// Spoken elapsed time, kept out of the label itself (which stays
    /// stable) so VoiceOver doesn't re-announce the whole row every second.
    /// `.updatesFrequently` lets VoiceOver re-poll this value periodically
    /// while focus stays on the row, instead of never hearing it at all.
    static func accessibilityValue(for session: SessionSnapshot) -> String? {
        guard let elapsed = session.elapsedSeconds, session.phase.isActive else { return nil }
        return format(elapsed)
    }

    /// Seconds drop out at the hour scale so long-running rows stay calm.
    static func format(_ seconds: Int) -> String {
        switch DurationTier(seconds: seconds) {
        case .seconds(let s): return "\(s)s"
        case .minutes(let m, let s): return "\(m)m \(s)s"
        case .hours(let h, let m): return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
    }
}

extension SourceSurface {
    var displayName: String {
        switch self {
        case .cli: "CLI"
        case .desktop: "Desktop"
        case .unknown: "Unknown source"
        }
    }
}
