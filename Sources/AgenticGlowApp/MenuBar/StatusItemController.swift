import AppKit
import Observation
import Symbols
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let symbolView = NSImageView()
    private let badgeView = NSView()
    private let popoverState = PopoverState()
    private var lastPresentation: StatusPresentation?
    private var lastCelebrationCount = 0
    private var celebrationResetTask: Task<Void, Never>?

    init(
        model: AppModel,
        preferences: PreferencesStore,
        claudeCredentialStore: any ClaudeSessionCredentialStoring,
        openIntegrations: @escaping () -> Void
    ) {
        self.model = model
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: SessionListView(
                model: model,
                preferences: preferences,
                popoverState: popoverState,
                claudeCredentialStore: claudeCredentialStore,
                openIntegrations: openIntegrations
            )
        )

        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.identifier = NSUserInterfaceItemIdentifier("AgenticGlow.StatusItem")
        item.button?.setAccessibilityIdentifier("AgenticGlow.StatusItem")
        if let button = item.button {
            symbolView.translatesAutoresizingMaskIntoConstraints = false
            symbolView.imageScaling = .scaleProportionallyDown
            button.addSubview(symbolView)
            badgeView.translatesAutoresizingMaskIntoConstraints = false
            badgeView.wantsLayer = true
            badgeView.layer?.cornerRadius = 3
            badgeView.isHidden = true
            button.addSubview(badgeView)
            NSLayoutConstraint.activate([
                symbolView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 3),
                symbolView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                symbolView.widthAnchor.constraint(equalToConstant: 18),
                symbolView.heightAnchor.constraint(equalToConstant: 18),
                badgeView.trailingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 1),
                badgeView.topAnchor.constraint(equalTo: symbolView.topAnchor, constant: -1),
                badgeView.widthAnchor.constraint(equalToConstant: 6),
                badgeView.heightAnchor.constraint(equalToConstant: 6)
            ])
        }
        observeModel()
    }

    func stop() {
        symbolView.removeAllSymbolEffects()
    }

    func popoverDidClose(_ notification: Notification) {
        popoverState.isPresented = false
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            popoverState.isPresented = false
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popoverState.isPresented = true
            Task { await model.refreshUsage(.popoverOpened) }
            Task { await model.refreshServiceStatus() }
        }
    }

    private func observeModel() {
        withObservationTracking {
            update()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeModel()
            }
        }
    }

    private func update() {
        let presentation = StatusPresentation(
            resolved: model.resolved,
            showTimer: model.showTimer,
            reduceMotion: model.reduceMotion,
            lowAllowance: model.hasLowAllowance
        )
        let celebrating = beginCelebrationIfNeeded()
        guard presentation != lastPresentation else { return }
        lastPresentation = presentation
        let image = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: nil
        )
        image?.isTemplate = true
        symbolView.image = image
        symbolView.contentTintColor = celebrating ? .systemGreen : presentation.color
        badgeView.isHidden = !presentation.showsAllowanceBadge
        badgeView.layer?.backgroundColor = NSColor.systemOrange.cgColor
        item.button?.image = nil
        item.button?.title = presentation.title.isEmpty ? "" : "     \(presentation.title)"
        item.length = presentation.title.isEmpty ? 24 : NSStatusItem.variableLength
        item.button?.setAccessibilityLabel(presentation.accessibilityLabel)
        configureAnimation(enabled: presentation.animates)
    }

    /// Briefly turns the icon green (with a bounce where available) when a
    /// weekly allowance window rolls over, then restores the live state.
    private func beginCelebrationIfNeeded() -> Bool {
        guard model.weeklyResetCount != lastCelebrationCount else {
            return celebrationResetTask != nil
        }
        lastCelebrationCount = model.weeklyResetCount
        symbolView.contentTintColor = .systemGreen
        if !model.reduceMotion, #available(macOS 15.0, *) {
            symbolView.addSymbolEffect(.bounce, options: .repeat(3))
        }
        celebrationResetTask?.cancel()
        celebrationResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.celebrationResetTask = nil
            self.lastPresentation = nil
            self.update()
        }
        return true
    }

    private func configureAnimation(enabled: Bool) {
        symbolView.removeAllSymbolEffects()
        if enabled, #available(macOS 15.0, *) {
            let effect: RotateSymbolEffect = .rotate
            addIndefiniteEffect(
                effect,
                options: .repeating.speed(0.25)
            )
        }
    }

    private func addIndefiniteEffect<Effect>(
        _ effect: Effect,
        options: SymbolEffectOptions
    ) where Effect: IndefiniteSymbolEffect & SymbolEffect {
        symbolView.addSymbolEffect(effect, options: options)
    }
}

@MainActor
@Observable
final class PopoverState {
    var isPresented = false
}
